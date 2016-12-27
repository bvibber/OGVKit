//
//  OGVFrameView.m
//  OGVKit
//
//  Created by Brion on 11/6/13.
//  Copyright (c) 2013-2015 Brion Vibber. All rights reserved.
//

#import "OGVKit.h"

// In the world of GL there are no rectangles.
// There are only triangles.
// THERE IS NO SPOON.
static const GLuint rectanglePoints = 6;

@implementation OGVFrameView {
    CMSampleBufferRef sampleBuffer;
    GLuint vertexShader;
    GLuint fragmentShader;
    GLuint program;
    CVOpenGLESTextureCacheRef textureCache;
    NSArray *texturesToFree;
}

#pragma mark GLKView method overrides

- (void)drawRect:(CGRect)rect
{
    [self setupGLStuff];
    
    // Clear out any old textures if we have some left over.
    // We didn't CFRelease() them during last drawing to make sure safe
    texturesToFree = nil;
    CVOpenGLESTextureCacheFlush(textureCache, 0);

    if (sampleBuffer) {
        GLuint rectangleBuffer = [self setupPosition:@"aPosition"
                                               width:self.frame.size.width
                                              height:self.frame.size.height];

        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        CGSize imageSize = CVImageBufferGetEncodedSize(imageBuffer);
        
        CVOpenGLESTextureRef textureY = [self cacheTextureFormat:GL_LUMINANCE
                                                           plane:0
                                                           width:imageSize.width
                                                          height:imageSize.height];
        [self attachTexture:textureY
                       name:@"uTextureY"
                        reg:GL_TEXTURE0
                      index:0];

        CVOpenGLESTextureRef textureCbCr = [self cacheTextureFormat:GL_LUMINANCE_ALPHA
                                                              plane:1
                                                              width:imageSize.width / 2
                                                             height:imageSize.height / 2];
        [self attachTexture:textureCbCr
                       name:@"uTextureCbCr"
                        reg:GL_TEXTURE1
                      index:1];
        
        GLuint lumaPositionBuffer = [self setupTexturePosition:@"aLumaPosition"
                                                       texture:textureY];
        
        GLuint chromaPositionBuffer = [self setupTexturePosition:@"aChromaPosition"
                                                         texture:textureCbCr];
        
        glDrawArrays(GL_TRIANGLES, 0, rectanglePoints);
        [self debugCheck];
        
        glDeleteBuffers(1, &chromaPositionBuffer);
        [self debugCheck];
        glDeleteBuffers(1, &lumaPositionBuffer);
        [self debugCheck];
        glDeleteBuffers(1, &rectangleBuffer);
        [self debugCheck];
        
        // These'll get freed on next draw, so don't have to issue glFlush()
        texturesToFree = @[(__bridge id)textureY, (__bridge id)textureCbCr];
        CFRelease(textureY);
        CFRelease(textureCbCr);
    } else {
        glClearColor(0, 0, 0, 1);
        [self debugCheck];
        
        glDepthMask(GL_TRUE); // voodoo from http://stackoverflow.com/questions/5470822/ios-opengl-es-logical-buffer-loads
        
        glClear(GL_DEPTH_BUFFER_BIT | GL_COLOR_BUFFER_BIT);
        [self debugCheck];
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
    if (sampleBuffer) {
        CFRelease(sampleBuffer);
    }
}

#pragma mark OGVFrameView methods

// call me on the main thread
- (void)drawFrame:(OGVVideoBuffer *)buffer
{
    // Copy into GPU memory
    if (sampleBuffer) {
        CFRelease(sampleBuffer);
    }
    sampleBuffer = [buffer copyAsSampleBuffer];

    [self setNeedsDisplay];
}

- (void)drawSampleBuffer:(CMSampleBufferRef)buffer;
{
    if (sampleBuffer) {
        CFRelease(sampleBuffer);
    }
    sampleBuffer = buffer;
    CFRetain(sampleBuffer);
    
    [self setNeedsDisplay];
}

- (void)clearFrame
{
    if (sampleBuffer) {
        CFRelease(sampleBuffer);
        sampleBuffer = nil;
    }
    [self setNeedsDisplay];
}

#pragma mark Private methods

-(void)setupGLStuff
{
    if (!program) {
        CVReturn ret = CVOpenGLESTextureCacheCreate(NULL,
                                                    NULL, // cache attribs,
                                                    self.context,
                                                    NULL, // texture attribs,
                                                    &textureCache);
        if (ret != kCVReturnSuccess) {
            [NSException raise:@"OGVFrameViewException"
                        format:@"CVOpenGLESTextureCacheCreate failed (%d)", ret];
        }

        vertexShader = [self compileShader:GL_VERTEX_SHADER];
        fragmentShader = [self compileShader:GL_FRAGMENT_SHADER];
        
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
    }
}

-(GLuint)compileShader:(GLenum)shaderType
{
    NSBundle *bundle = [[OGVKit singleton] resourceBundle];
    NSString *ext = [self extensionForShaderType:shaderType];
    NSString *path = [bundle pathForResource:@"OGVFrameView" ofType:ext];
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


-(GLuint)setupPosition:(NSString *)varname width:(int)width height:(int)height
{
    // Set up our rectangle as a buffer...
    GLuint rectangleBuffer;
    glGenBuffers(1, &rectangleBuffer);
    [self debugCheck];
    
    glBindBuffer(GL_ARRAY_BUFFER, rectangleBuffer);
    [self debugCheck];
    
    // Set the aspect ratio
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CGSize displaySize = CVImageBufferGetDisplaySize(imageBuffer);

    GLfloat frameAspect = displaySize.width / displaySize.height;
    GLfloat viewAspect = (float)width / (float)height;
    GLfloat scaleX, scaleY;

    if (frameAspect >= viewAspect) {
        scaleX = 1.0f;
        scaleY = viewAspect / frameAspect;
    } else {
        scaleY = 1.0f;
        scaleX = frameAspect / viewAspect;
    }
    
    GLfloat rectangle[] = {
        // First triangle (top left, clockwise)
        -scaleX, -scaleY,
        +scaleX, -scaleY,
        -scaleX, +scaleY,
        
        // Second triangle (bottom right, clockwise)
        -scaleX, +scaleY,
        +scaleX, -scaleY,
        +scaleX, +scaleY
    };

    glBufferData(GL_ARRAY_BUFFER, rectanglePoints * sizeof(GLfloat) * 2, rectangle, GL_STATIC_DRAW);
    [self debugCheck];
    
    // Assign the rectangle to the position input on the vertex shader
    GLuint positionLocation = glGetAttribLocation(program, "aPosition");
    [self debugCheck];
    
    glEnableVertexAttribArray(positionLocation);
    [self debugCheck];
    
    glVertexAttribPointer(positionLocation, 2, GL_FLOAT, false, 0, 0);
    [self debugCheck];
    
    return rectangleBuffer;
}

-(GLuint)setupTexturePosition:(NSString *)varname texture:(CVOpenGLESTextureRef)texture
{
    GLfloat lowerLeft[2];
    GLfloat lowerRight[2];
    GLfloat upperRight[2];
    GLfloat upperLeft[2];
    CVOpenGLESTextureGetCleanTexCoords(texture, lowerLeft, lowerRight, upperRight, upperLeft);

    const GLfloat textureRectangle[] = {
        lowerLeft[0], lowerLeft[1],
        lowerRight[0], lowerRight[1],
        upperLeft[0], upperLeft[1],

        upperLeft[0], upperLeft[1],
        lowerRight[0], lowerRight[1],
        upperRight[0], upperRight[1]
    };
    
    GLuint texturePositionBuffer;
    glGenBuffers(1, &texturePositionBuffer);
    [self debugCheck];
    glBindBuffer(GL_ARRAY_BUFFER, texturePositionBuffer);
    [self debugCheck];
    glBufferData(GL_ARRAY_BUFFER, rectanglePoints * sizeof(GLfloat) * 2, textureRectangle, GL_STATIC_DRAW);
    [self debugCheck];
    
    GLuint texturePositionLocation = glGetAttribLocation(program, [varname UTF8String]);
    [self debugCheck];
    glEnableVertexAttribArray(texturePositionLocation);
    [self debugCheck];
    glVertexAttribPointer(texturePositionLocation, 2, GL_FLOAT, false, 0, 0);
    [self debugCheck];
    
    return texturePositionBuffer;
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

-(CVOpenGLESTextureRef)cacheTextureFormat:(GLenum)pixelFormat
                                    plane:(int)plane
                                    width:(int)width
                                   height:(int)height
{
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVOpenGLESTextureRef texture = NULL;
    CVReturn ret = CVOpenGLESTextureCacheCreateTextureFromImage(NULL, // allocator
                                                                textureCache,
                                                                imageBuffer,
                                                                NULL, // textureAttributes,
                                                                GL_TEXTURE_2D,
                                                                pixelFormat,
                                                                width,
                                                                height,
                                                                pixelFormat,
                                                                GL_UNSIGNED_BYTE,
                                                                plane,
                                                                &texture);
    if (ret != kCVReturnSuccess) {
        [NSException raise:@"OGVFrameViewException"
                    format:@"CVOpenGLESTextureCacheCreateTextureFromImage failed (%d)", ret];
    }
    return texture;
}

-(void)debugCheck
{
#if 0
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
