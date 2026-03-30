//
//  PixelCanvas.metal
//  pixcen
//
//  Created by Jack Pearse on 21.03.21.
//  Fullscreen Metal shader for C64 pixel rendering.
//  Handles zoom, pan, border, pixel grid, and cell grid.
//
#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;

// Must match Swift Uniforms struct layout exactly (96 bytes)
struct Uniforms {
    float2 viewportSize;      // drawable size in pixels (Retina)
    float2 pixelBufferSize;   // C64 buffer size (e.g. 160x200)
    float  zoom;              // continuous zoom factor (includes Retina scale)
    float  pixelWidth;        // pixel width (1=hires, 2=multicolor)
    float2 pan;               // pan offset in C64-pixel-space
    int    showPixelGrid;
    int    showCellGrid;
    int    cellWidth;         // cell width in C64 pixels (e.g. 4)
    int    cellHeight;        // cell height in C64 pixels (e.g. 8)
    float4 borderColor;
    float4 gridColor;
    float4 cellGridColor;
    float4 selectionRect;     // (x, y, w, h) in C64 pixels; w=0 means no selection
    float  time;              // animation time for marching ants
    float3 _padding3;
};

// C64 palette is passed as a buffer from CPU (supports runtime palette switching)

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

constant float2 quadVertices[6] = {
    float2(-1, -1), float2(-1,  1), float2( 1,  1),
    float2(-1, -1), float2( 1,  1), float2( 1, -1)
};

vertex VertexOut copyVertex(unsigned short vid [[vertex_id]]) {
    VertexOut out;
    out.position = float4(quadVertices[vid], 0, 1);
    float2 tc = quadVertices[vid] * 0.5 + 0.5;
    out.texCoord = float2(tc.x, 1.0 - tc.y);  // Flip Y: NDC bottom→top to screen top→bottom
    return out;
}

// Fragment shader: fullscreen quad renders the entire viewport.
//
// Coordinate mapping:
//   screenPos = texCoord * viewportSize         (drawable pixels, origin top-left)
//   panScreen = pan * zoom * (pixelWidth, 1)    (pan converted to screen space)
//   docPos    = screenPos + panScreen           (position in zoomed document)
//   bufX      = docPos.x / (zoom * pixelWidth)  (C64 pixel X)
//   bufY      = docPos.y / zoom                  (C64 pixel Y)
//
// The bitmap occupies document rect (0,0) to (zoom*mx*pw, zoom*my).
// Everything outside is border color.

fragment float4 copyFragment(VertexOut in [[stage_in]],
                             constant Uniforms &u [[buffer(0)]],
                             constant float4 *palette [[buffer(1)]],
                             texture2d<uint, access::read> pixelBuffer [[texture(0)]])
{
    float2 screenPos = in.texCoord * u.viewportSize;

    float z  = u.zoom;
    float pw = u.pixelWidth;
    float mx = u.pixelBufferSize.x;
    float my = u.pixelBufferSize.y;

    // Convert pan from C64-pixel-space to screen-space
    float2 panScreen = float2(u.pan.x * z * pw, u.pan.y * z);

    // Document position: screen pixel + pan offset
    float2 docPos = screenPos + panScreen;

    // Bitmap extent in document space
    float docW = z * mx * pw;
    float docH = z * my;

    // Outside bitmap → border
    if (docPos.x < 0 || docPos.x >= docW ||
        docPos.y < 0 || docPos.y >= docH) {
        return u.borderColor;
    }

    // Map to C64 buffer coordinates
    float bufXf = docPos.x / (z * pw);
    float bufYf = docPos.y / z;

    int bufX = clamp(int(bufXf), 0, int(mx) - 1);
    int bufY = clamp(int(bufYf), 0, int(my) - 1);

    // Read color index from texture
    uint pixelIndex = min(pixelBuffer.read(uint2(bufX, bufY)).r, 15u);
    float4 color = palette[pixelIndex];

    // Grid overlay when zoomed in enough
    if (z > 4.0) {
        // Position within the current C64 pixel (in screen/document pixels)
        float fracX = docPos.x - float(bufX) * z * pw;
        float fracY = docPos.y - float(bufY) * z;

        // Cell grid: 2px lines at cell boundaries
        if (u.showCellGrid != 0) {
            if ((bufX % u.cellWidth == 0 && fracX < 2.0) ||
                (bufY % u.cellHeight == 0 && fracY < 2.0)) {
                return u.cellGridColor;
            }
        }

        // Pixel grid: 1px lines at every C64 pixel boundary
        if (u.showPixelGrid != 0) {
            if (fracX < 1.0 || fracY < 1.0) {
                return mix(color, u.gridColor, 0.4);
            }
        }
    }

    // Selection rectangle (marching ants / dashed outline)
    // Border is always 1 screen pixel thin regardless of zoom level
    if (u.selectionRect.z > 0 && u.selectionRect.w > 0) {
        float selX = u.selectionRect.x;
        float selY = u.selectionRect.y;
        float selW = u.selectionRect.z;
        float selH = u.selectionRect.w;

        // Convert selection edges to document space
        float selL = selX * z * pw;             // left edge
        float selR = (selX + selW) * z * pw;    // right edge
        float selT = selY * z;                  // top edge
        float selB = (selY + selH) * z;         // bottom edge

        // Border width scales with zoom: thin at overview, thicker when zoomed in
        float bw = clamp(z * pw * 0.1, 1.0, 4.0);
        bool onLeft   = (docPos.x >= selL - bw && docPos.x < selL + bw);
        bool onRight  = (docPos.x >= selR - bw && docPos.x < selR + bw);
        bool onTop    = (docPos.y >= selT - bw && docPos.y < selT + bw);
        bool onBottom = (docPos.y >= selB - bw && docPos.y < selB + bw);

        bool inXRange = (docPos.x >= selL - bw && docPos.x < selR + bw);
        bool inYRange = (docPos.y >= selT - bw && docPos.y < selB + bw);

        if ((onLeft && inYRange) || (onRight && inYRange) ||
            (onTop && inXRange) || (onBottom && inXRange)) {
            // Marching ants: animated, dash length scales with zoom
            float dashLen = clamp(z * pw * 0.3, 4.0, 12.0);
            float march = docPos.x + docPos.y + u.time * 40.0;
            int pattern = int(march / dashLen);
            color = (pattern % 2 == 0) ? float4(1,1,1,1) : float4(0,0,0,1);
        }
    }

    return color;
}
