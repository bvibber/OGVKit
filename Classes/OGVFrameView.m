//
//  OGVFrameView.m
//  OGVKit
//
//  Created by Brion on 11/6/13.
//  Copyright (c) 2013-2015 Brion Vibber. All rights reserved.
//

#import "OGVKit.h"

#import <OpenGLES/ES2/glext.h>

// Uncomment to check for OpenGL ES errors. Slows rendering.
//#define DEBUG_GL

// In the world of GL there are no rectangles.
// There are only triangles.
// THERE IS NO SPOON.
static const GLuint rectanglePoints = 6;

// Gleefully borrowed from https://github.com/mbebenita/Broadway/blob/master/Player/YUVCanvas.js
static const GLfloat conversionMatrixBT709[] = {
    1.16438,  0.00000,  1.79274, -0.97295,
    1.16438, -0.21325, -0.53291,  0.30148,
    1.16438,  2.11240,  0.00000, -1.13340,
    0, 0, 0, 1
};
static const GLfloat conversionMatrixBT601[] = {
    1.16438,  0.00000,  1.59603, -0.87079,
    1.16438, -0.39176, -0.81297,  0.52959,
    1.16438,  2.01723,  0.00000, -1.08139,
    0, 0, 0, 1
};

@implementation OGVFrameView {
    OGVVideoFormat *format;
    OGVVideoFormat *lastFormat;
    CVPixelBufferRef pixelBufferY;
    CVPixelBufferRef pixelBufferCb;
    CVPixelBufferRef pixelBufferCr;
    GLuint vertexShader;
    GLuint fragmentShader;
    GLuint program;
    GLuint positionBuffer;
    GLuint texPositionBuffer;
    CVOpenGLESTextureCacheRef textureCache;
    NSArray *texturesToFree;
}

#pragma mark GLKView method overrides

- (void)drawRect:(CGRect)rect
{
    if (textureCache) {
        // Clear out any old textures if we have some left over.
        // We didn't CFRelease() them during last drawing to make sure safe
        texturesToFree = nil;
    }

    [self setupGLStuff];

    glClearColor(0, 0, 0, 1);
    [self debugCheck];
    
    glDepthMask(GL_TRUE); // voodoo from http://stackoverflow.com/questions/5470822/ios-opengl-es-logical-buffer-loads

    glClear(GL_DEPTH_BUFFER_BIT | GL_COLOR_BUFFER_BIT);
    [self debugCheck];

    if (format) {
        if (![format isEqual:lastFormat]) {
            lastFormat = format;

            [self setupConversionMatrix];
            
            // @todo only update buffers when the format or layer size changes
            [self updateRectangleWidth:self.frame.size.width height:self.frame.size.height];
            
            // Just show the clean aperture rectangle!
            [self updateTexturePosition];
        }
        
        [self attachPositionBuffer:positionBuffer varname:@"aPosition"];
        [self attachPositionBuffer:texPositionBuffer varname:@"aTexPosition"];

        // First plane holds Y
        CVOpenGLESTextureRef textureY = [self cacheTexture:pixelBufferY];
        [self attachTexture:textureY name:@"uTextureY" reg:GL_TEXTURE0 index:0];
        
        // Second plane holds Cb
        CVOpenGLESTextureRef textureCb = [self cacheTexture:pixelBufferCb];
        [self attachTexture:textureCb name:@"uTextureCb" reg:GL_TEXTURE1 index:1];

        // Third plane holds Cr
        CVOpenGLESTextureRef textureCr = [self cacheTexture:pixelBufferCr];
        [self attachTexture:textureCr name:@"uTextureCr" reg:GL_TEXTURE2 index:2];

        // Note: OpenGL ES Analysis in Instruments reports a warning about
        // "Uninitialized Texture Data" which seems to be triggered by use of
        // CVOpenGLESTextureCache. This seems to be harmless.
        glDrawArrays(GL_TRIANGLES, 0, rectanglePoints);
        [self debugCheck];
        
        // These'll get freed or reused on next draw, after drawing is complete.
        texturesToFree = @[(__bridge id)textureY, (__bridge id)textureCb, (__bridge id)textureCr];
        CFRelease(textureY);
        CFRelease(textureCb);
        CFRelease(textureCr);

        CVOpenGLESTextureCacheFlush(textureCache, 0);
    }
    
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    // Make sure we update the screen after resize,
    // it doesn't seem to trigger otherwise.
    [self setNeedsDisplay];
}

-(void)dealloc
{
    if (textureCache) {
        CFRelease(textureCache);
    }
    if (pixelBufferY) {
        CFRelease(pixelBufferY);
    }
    if (pixelBufferCb) {
        CFRelease(pixelBufferCb);
    }
    if (pixelBufferCr) {
        CFRelease(pixelBufferCr);
    }
}

#pragma mark OGVFrameView methods

// safe to call on background thread
- (void)drawFrame:(OGVVideoBuffer *)buffer
{
    // Copy into GPU memory
    OGVVideoFormat *nextFormat = buffer.format;
    CVPixelBufferRef nextY = [buffer copyPixelBufferWithPlane:OGVVideoPlaneIndexY];
    CVPixelBufferRef nextCb = [buffer copyPixelBufferWithPlane:OGVVideoPlaneIndexCb];
    CVPixelBufferRef nextCr = [buffer copyPixelBufferWithPlane:OGVVideoPlaneIndexCr];
    dispatch_async(dispatch_get_main_queue(), ^{
        format = nextFormat;
        if (pixelBufferY) {
            CFRelease(pixelBufferY);
        }
        if (pixelBufferCb) {
            CFRelease(pixelBufferCb);
        }
        if (pixelBufferCr) {
            CFRelease(pixelBufferCr);
        }
        pixelBufferY = nextY;
        pixelBufferCb = nextCb;
        pixelBufferCr = nextCr;
        
        [self setNeedsDisplay];
    });
}

- (void)clearFrame
{
    dispatch_async(dispatch_get_main_queue(), ^{
        format = nil;
        if (pixelBufferY) {
            CFRelease(pixelBufferY);
            pixelBufferY = NULL;
        }
        if (pixelBufferCb) {
            CFRelease(pixelBufferCb);
            pixelBufferCb = NULL;
        }
        if (pixelBufferCr) {
            CFRelease(pixelBufferCr);
            pixelBufferCr = NULL;
        }
        [self setNeedsDisplay];
    });
}

#pragma mark Private methods

-(void)setupGLStuff
{
    if (!textureCache) {
        CVReturn ret = CVOpenGLESTextureCacheCreate(NULL,
                                                    NULL, // cache attribs,
                                                    self.context,
                                                    NULL, // texture attribs,
                                                    &textureCache);
        if (ret != kCVReturnSuccess) {
            [NSException raise:@"OGVFrameViewException"
                        format:@"CVOpenGLESTextureCacheCreate failed (%d)", ret];
        }
    }
    
    if (!program) {
        vertexShader = [self compileShader:@"OGVFrameView" type:GL_VERTEX_SHADER];
        fragmentShader = [self compileShader:@"OGVFrameView" type:GL_FRAGMENT_SHADER];
        
        program = glCreateProgram();
        [self debugCheck];
        glAttachShader(program, vertexShader);
        [self debugCheck];
        glAttachShader(program, fragmentShader);
        [self debugCheck];
        glLinkProgram(program);
        [self debugCheck];
        glUseProgram(program);
        [self debugCheck];

        positionBuffer = [self setupPositionBuffer:@"aPosition"];
        texPositionBuffer = [self setupPositionBuffer:@"aTexPosition"];
    }
}

-(GLuint)compileShader:(NSString *)name type:(GLenum)shaderType
{
    NSBundle *bundle = [[OGVKit singleton] resourceBundle];
    NSString *ext = [self extensionForShaderType:shaderType];
    NSString *path = [bundle pathForResource:name ofType:ext];
    NSData *source = [NSData dataWithContentsOfFile:path];

    GLuint shader = glCreateShader(shaderType);
    [self debugCheck];
    
    const GLchar *str = (const GLchar *)[source bytes];
    const GLint len = (const GLint)[source length];
    glShaderSource(shader, 1, &str, &len);
    [self debugCheck];
    glCompileShader(shader);
    [self debugCheck];

    // todo: error handling? meh whatever
    
    return shader;
}

- (NSString *)extensionForShaderType:(GLenum)shaderType
{
    switch (shaderType) {
        case GL_VERTEX_SHADER:
            return @"vsh";
        case GL_FRAGMENT_SHADER:
            return @"fsh";
        default:
            abort();
    }
}

-(void)setupConversionMatrix
{
    GLfloat *matrix;
    switch (format.colorSpace) {
        case OGVColorSpaceBT601:
            // SDTV NTSC
            matrix = conversionMatrixBT601;
        case OGVColorSpaceBT709:
            // HDTV
            matrix = conversionMatrixBT709;
            break;
        default:
            // If unknown default to BT601 NTSC-style
            matrix = conversionMatrixBT601;
    }
    GLuint loc = glGetUniformLocation(program, "uConversionMatrix");
    glUniformMatrix4fv(loc, 1, GL_FALSE, matrix);
}

-(GLuint)setupPositionBuffer:(NSString *)varname
{
    GLuint buffer;
    glGenBuffers(1, &buffer);
    [self debugCheck];

    glBindBuffer(GL_ARRAY_BUFFER, buffer);
    [self debugCheck];
    
    return buffer;
}

-(void)fillPositionBuffer:(GLuint)bufferId
                     left:(GLfloat)left
                    right:(GLfloat)right
                      top:(GLfloat)top
                   bottom:(GLfloat)bottom
{
    const GLfloat rectangle[] = {
        // First triangle (top left, clockwise)
        left, bottom,
        right, bottom,
        left, top,
        
        // Second triangle (bottom right, clockwise)
        left, top,
        right, bottom,
        right, top
    };
    
    glBindBuffer(GL_ARRAY_BUFFER, bufferId);
    [self debugCheck];

    glBufferData(GL_ARRAY_BUFFER, rectanglePoints * sizeof(GLfloat) * 2, rectangle, GL_STATIC_DRAW);
    [self debugCheck];
}

-(void)attachPositionBuffer:(GLuint)bufferId
                    varname:(NSString *)varname
{
    glBindBuffer(GL_ARRAY_BUFFER, bufferId);
    [self debugCheck];

    // Assign the rectangle to the position input on the vertex shader
    GLuint positionLocation = glGetAttribLocation(program, [varname UTF8String]);
    [self debugCheck];
    
    glEnableVertexAttribArray(positionLocation);
    [self debugCheck];
    
    glVertexAttribPointer(positionLocation, 2, GL_FLOAT, false, 0, 0);
    [self debugCheck];
}

-(GLuint)updateRectangleWidth:(int)width
                       height:(int)height
{
    // Set the aspect ratio
    GLfloat frameAspect = (float)format.pictureWidth / (float)format.pictureHeight;
    GLfloat viewAspect = (float)width / (float)height;
    GLfloat scaleX, scaleY;

    if (frameAspect >= viewAspect) {
        scaleX = 1.0f;
        scaleY = viewAspect / frameAspect;
    } else {
        scaleY = 1.0f;
        scaleX = frameAspect / viewAspect;
    }
    
    [self fillPositionBuffer:positionBuffer
                        left:-scaleX
                       right:scaleX
                         top:scaleY
                      bottom:-scaleY];
}

-(void)updateTexturePosition
{
    // Ideally we'd use CVOpenGLESTextureGetCleanTexCoords, but this doesn't
    // work for some mysteeeeeerious reason on the one-channel buffers I'm
    // creating for the planes.
    GLfloat left = (GLfloat)format.pictureOffsetX / (GLfloat)format.frameWidth;
    GLfloat right = ((GLfloat)format.pictureOffsetX + (GLfloat)format.pictureWidth) / (GLfloat)format.frameWidth;
    GLfloat top = ((GLfloat)format.pictureOffsetY / (GLfloat)format.frameHeight);
    GLfloat bottom = (((GLfloat)format.pictureOffsetY + (GLfloat)format.pictureHeight) / (GLfloat)format.frameHeight);
    
    [self fillPositionBuffer:texPositionBuffer
                        left:left
                       right:right
                         top:top
                      bottom:bottom];
}

-(void)attachTexture:(CVOpenGLESTextureRef)texture
                name:(NSString *)varname
                 reg:(GLenum)reg
               index:(GLuint)index
{
    
    glActiveTexture(reg);
    [self debugCheck];
    glBindTexture(CVOpenGLESTextureGetTarget(texture), CVOpenGLESTextureGetName(texture));
    [self debugCheck];

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    [self debugCheck];
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    [self debugCheck];
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    [self debugCheck];
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    [self debugCheck];

    GLuint uniformLoc = glGetUniformLocation(program, [varname UTF8String]);
    [self debugCheck];
    glUniform1i(uniformLoc, index);
    [self debugCheck];
}

-(CVOpenGLESTextureRef)cacheTexture:(CVPixelBufferRef)pixelBuffer
{
    CVOpenGLESTextureRef texture = NULL;
    CGSize encodedSize = CVImageBufferGetEncodedSize(pixelBuffer);
    CVReturn ret = CVOpenGLESTextureCacheCreateTextureFromImage(NULL, // allocator
                                                                textureCache,
                                                                pixelBuffer,
                                                                NULL, // textureAttributes,
                                                                GL_TEXTURE_2D,
                                                                GL_LUMINANCE,
                                                                encodedSize.width,
                                                                encodedSize.height,
                                                                GL_LUMINANCE,
                                                                GL_UNSIGNED_BYTE,
                                                                0,
                                                                &texture);
    if (ret != kCVReturnSuccess) {
        [NSException raise:@"OGVFrameViewException"
                    format:@"CVOpenGLESTextureCacheCreateTextureFromImage failed (%d)", ret];
    }
    return texture;
}

-(void)debugCheck
{
#ifdef DEBUG_GL
    GLenum err = glGetError();
    if (err != GL_NO_ERROR) {
        NSString *str = [self stringForGLError:err];
        NSLog(@"GL error: %d %@", (int)err, str);
        @throw [NSException exceptionWithName:@"OGVFrameViewException"
                                       reason:str
                                     userInfo:@{@"glError": @((int)err),
                                                @"glErrorString": str}];
    }
#endif
}

-(NSString *)stringForGLError:(GLenum)err
{
    switch (err) {
        case GL_NO_ERROR: return @"GL_NO_ERROR";
        case GL_INVALID_ENUM: return @"GL_INVALID_ENUM";
        case GL_INVALID_VALUE: return @"GL_INVALID_VALUE";
        case GL_INVALID_OPERATION: return @"GL_INVALID_OPERATION";
        case GL_INVALID_FRAMEBUFFER_OPERATION: return @"GL_INVALID_FRAMEBUFFER_OPERATION";
        case GL_OUT_OF_MEMORY: return @"GL_OUT_OF_MEMORY";
        default: return @"Unknown error";
    }
}

@end
