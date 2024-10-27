#import <Foundation/Foundation.h>
#include <Metal/Metal.h>
#import <Cocoa/Cocoa.h>
#import <MetalKit/MetalKit.h>
#import "Foundation/Foundation.h"
#import "CoreFoundation/CoreFoundation.h"

#import "shader_types.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>
@end

@interface ViewController : NSViewController<MTKViewDelegate>
@end

// Number of rectangles to draw
#define rectCount 1

@implementation ViewController {
	MTKView *view;

	id<MTLDevice> device;

	// The render pipeline generated from the vertex and fragment shaders in the .metal shader file.
	id<MTLRenderPipelineState> pipeline_state;

	// The command queue used to pass commands to the device.
	id<MTLCommandQueue> command_queue;

	// Vertex buffer for the rects
	id<MTLBuffer> rectVertexBuffer;
	id<MTLBuffer> rectUniformBuffer;
	id<MTLBuffer> uniformsBuffer;

	// Allocate memory for rectangle uniforms
	PerRectUniforms rectUniforms[rectCount];

	Uniforms uniforms;

	// The current size of the view, used as an input to the vertex shader.
	vector_float2 viewport_size;
}

- (void)viewDidLoad {
	[super viewDidLoad];

	// Set the view to use the default device
	view = (MTKView *)self.view;
	// [[view layer] setOpaque: NO];

	view.colorPixelFormat = MTLPixelFormatRGBA16Float;
	// view.colorPixelFormat = MTLPixelFormatBGRA8Unorm_sRGB;
	// view.colorspace = view.window.colorSpace.CGColorSpace;
	view.colorspace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);

	device = MTLCreateSystemDefaultDevice();
	view.device = device;

	NSAssert(device, @"Metal is not supported on this device");

	NSError *error;

	// Load all the shader files with a .metal file extension in the project.
	// id<MTLLibrary> defaultLibrary = [device newDefaultLibrary];
	// [device newLibraryWithFile: ""];
	NSURL *shaderURL = [[NSBundle mainBundle] URLForResource:@"shaders" withExtension:@"metallib"];
	id<MTLLibrary> library = [device newLibraryWithURL: shaderURL error:&error];

	if (!library || error) {
		NSLog(@"No shader library! Error: %@", error.localizedDescription);
	}

	id<MTLFunction> vertexFunction = [library newFunctionWithName:@"rect_vertex_shader"];
	id<MTLFunction> fragmentFunction = [library newFunctionWithName:@"rect_fragment_shader"];

	// Configure a pipeline descriptor that is used to create a pipeline state.
	MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
	pipelineStateDescriptor.label = @"Simple Pipeline";
	pipelineStateDescriptor.vertexFunction = vertexFunction;
	pipelineStateDescriptor.fragmentFunction = fragmentFunction;
	pipelineStateDescriptor.colorAttachments[0].pixelFormat                 = view.colorPixelFormat;
	pipelineStateDescriptor.colorAttachments[0].blendingEnabled             = YES;
	pipelineStateDescriptor.colorAttachments[0].sourceRGBBlendFactor        = MTLBlendFactorOne;
	pipelineStateDescriptor.colorAttachments[0].sourceAlphaBlendFactor      = MTLBlendFactorOne;
	pipelineStateDescriptor.colorAttachments[0].destinationRGBBlendFactor   = MTLBlendFactorOneMinusSourceAlpha;
	pipelineStateDescriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
	pipelineStateDescriptor.colorAttachments[0].rgbBlendOperation           = MTLBlendOperationAdd;
	pipelineStateDescriptor.colorAttachments[0].alphaBlendOperation         = MTLBlendOperationAdd;

	pipeline_state = [device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor
																													 error:&error];

	// Pipeline State creation could fail if the pipeline descriptor isn't set up properly.
	//  If the Metal API validation is enabled, you can find out more information about what
	//  went wrong.  (Metal API validation is enabled by default when a debug build is run
	//  from Xcode.)
	NSAssert1(pipeline_state, @"Failed to create pipeline state: %@", error);

	// Create the command queue
	command_queue = [device newCommandQueue];

	static const vector_float2 rectVertices[] = {
    { -0.5, -0.5 }, // bottom-left
    {  0.5, -0.5 }, // bottom-right
    { -0.5,  0.5 }, // top-left
    {  0.5,  0.5 }, // top-right
	};

	// Create the vertex buffer
	rectVertexBuffer = [device newBufferWithBytes:rectVertices
                             length:sizeof(rectVertices)
                             options:MTLResourceStorageModeShared];
	[rectVertexBuffer setLabel: @"Vertex Buffer"];

	// Fill each PerRectUniforms with unique values for each rectangle
	for (int i = 0; i < rectCount; ++i) {
		rectUniforms[i] = (PerRectUniforms){
	    .origin = {0.0, 0.0},
	    .size = {700.0, 550.0},
	    .border_top = 1.0,
	    .border_right = 1.0,
	    .border_bottom = 1.0,
	    .border_left = 1.0,
	    .corner_radius_top = 20.0,
	    .corner_radius_bottom = 20.0,
	    .background_start = {0.0, 0.0},
	    .background_end = {1.0, 1.0},
	    .background_start_color = {1.0, 0.0, 0.0, 0.0}, // Red
	    .background_end_color = {0.0, 0.0, 1.0, 0.5},   // Blue
	    .border_start = {0.0, 0.0},
	    .border_end = {1.0, 0.0},
	    .border_start_color = {1.0, 1.0, 1.0, 0.5},     // White
	    .border_end_color = {1.0, 1.0, 1.0, 0.5}        // Green
		};
	}

	// Create the Metal buffer to store all PerRectUniforms
	rectUniformBuffer = [device newBufferWithBytes:rectUniforms
                              length:sizeof(PerRectUniforms) * rectCount
                              options:MTLResourceStorageModeShared];
	[rectUniformBuffer setLabel: @"Rect Uniform Buffer"];

	uniforms.viewport_size = viewport_size;
	uniforms.max_z_index = 1.0f; // Set this to your desired max Z index
	uniformsBuffer = [device newBufferWithBytes:&uniforms
                           length:sizeof(Uniforms)
                           options:MTLResourceStorageModeShared];
	[uniformsBuffer setLabel: @"Uniform Buffer"];

	view.delegate = self;

	// Initialize our renderer with the view size
	[self mtkView:view drawableSizeWillChange:view.drawableSize];
}

/// Called whenever view changes orientation or is resized
- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
		// Save the size of the drawable to pass to the vertex shader.
		viewport_size.x = size.width;
		viewport_size.y = size.height;
}

/// Called whenever the view needs to render a frame.
- (void)drawInMTKView:(nonnull MTKView *)mtk_view {
		// Create a new command buffer for each render pass to the current drawable.
		id<MTLCommandBuffer> commandBuffer = [command_queue commandBuffer];
		commandBuffer.label = @"MyCommand";

		// Obtain a renderPassDescriptor generated from the view's drawable textures.
		MTLRenderPassDescriptor *renderPassDescriptor = mtk_view.currentRenderPassDescriptor;

		if(renderPassDescriptor != nil) {
			renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
	    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.1, 1.0);
	    renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;

			// Create a render command encoder.
			id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
			renderEncoder.label = @"MyRenderEncoder";

			// Set the region of the drawable to draw into.
			[renderEncoder setViewport:(MTLViewport){0.0, 0.0, (double)(viewport_size.x), (double)viewport_size.y, 0.0, 1.0 }];
			[renderEncoder setRenderPipelineState:pipeline_state];

			uniforms.viewport_size = viewport_size * 0.5f;
			uniforms.max_z_index = 1.0f; // Set this to your desired max Z index

			// Update the buffer to reflect the changes
	    memcpy(uniformsBuffer.contents, &uniforms, sizeof(Uniforms));

			 // Bind the rectangle vertex buffer (the rectangle’s normalized vertices)
      [renderEncoder setVertexBuffer:rectVertexBuffer offset:0 atIndex:0];

      // Bind rect uniforms buffer (holds all PerRectUniforms instances for each rectangle)
      [renderEncoder setVertexBuffer:rectUniformBuffer offset:0 atIndex:1];

	    // Bind the uniforms buffer
	    [renderEncoder setVertexBuffer:uniformsBuffer offset:0 atIndex:2];

      // Draw each rectangle instance with the specified number of vertices (4 for a rectangle in triangle strip)
      [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4 instanceCount:rectCount];

			[renderEncoder endEncoding];

			// Schedule a present once the framebuffer is complete using the current drawable.
			[commandBuffer presentDrawable:mtk_view.currentDrawable];
		}

		// Finalize rendering here & push the command buffer to the GPU.
		[commandBuffer commit];
}


- (void)setRepresentedObject:(id)representedObject {
	[super setRepresentedObject:representedObject];

	// Update the view, if already loaded.
}

@end

@implementation AppDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
	// Insert code here to tear down your application
}


- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
	return YES;
}
@end

int main(int argument_count, const char *arguments[]) {
	return NSApplicationMain(argument_count, arguments);
}