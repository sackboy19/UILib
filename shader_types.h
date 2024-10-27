//
//  shader_types.h
//  UILib
//
//  Created by Daniel Valdes on 8/25/24.
//

/*
Abstract:
Header containing types and enum constants shared between Metal shaders and C/ObjC source
*/

#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

//  This structure defines the layout of vertices sent to the vertex
//  shader. This header is shared between the .metal shader and C code, to guarantee that
//  the layout of the vertex array in the C code matches the layout that the .metal
//  vertex shader expects.

struct PerRectUniforms {
  vector_float2 origin;               // Position of the rectangle in pixel space
  vector_float2 size;                 // Size of the rectangle

  float border_top;                   // Thickness of the top border
  float border_right;                 // Thickness of the right border
  float border_bottom;                // Thickness of the bottom border
  float border_left;                  // Thickness of the left border

  float corner_radius_top;            // Corner radius for the top corners
  float corner_radius_bottom;         // Corner radius for the bottom corners

  vector_float2 background_start;     // Start point of the background gradient in normalized space
  vector_float2 background_end;       // End point of the background gradient in normalized space
  vector_float4 background_start_color; // Start color of the background gradient
  vector_float4 background_end_color;   // End color of the background gradient

  vector_float2 border_start;         // Start point of the border gradient in normalized space
  vector_float2 border_end;           // End point of the border gradient in normalized space
  vector_float4 border_start_color;   // Start color of the border gradient
  vector_float4 border_end_color;     // End color of the border gradient
};

struct Uniforms {
  vector_float2 viewport_size;
  float max_z_index;
};

#endif /* ShaderTypes_h */
