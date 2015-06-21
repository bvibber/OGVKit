//
//  OGVFrameView.m
//  OGVKit
//
//  Created by Brion on 11/6/13.
//  Copyright (c) 2013 Brion Vibber. All rights reserved.
//

#import "OGVKit.h"

// In the world of GL there are no rectangles.
// There are only triangles.
// THERE IS NO SPOON.
static const GLuint rectanglePoints = 6;

@implementation OGVFrameView {
    OGVVideoFormat *format;
    OGVVideoBuffer *nextFrame;
    GLuint vertexShader;
    GLuint fragmentShader;
    GLuint program;
    GLuint textures[3];
    GLuint textureWidth[3];
    GLuint textureHeight[3];
}

#pragma mark GLKView method overrides

- (void)drawRect:(CGRect)rect
{
    [self setupGLStuff];
    
    glClearColor(0, 0, 0, 1);
    [self debugCheck];

    glDepthMask(GL_TRUE); // voodoo from http://stackoverflow.com/questions/5470822/ios-opengl-es-logical-buffer-loads
    glClear(GL_DEPTH_BUFFER_BIT | GL_COLOR_BUFFER_BIT);
    [self debugCheck];

    if (nextFrame) {
        GLuint rectangleBuffer = [self setupPosition:@"aPosition"
                                               width:self.frame.size.width
                                              height:self.frame.size.height];
        
        GLuint lumaPositionBuffer = [self setupTexturePosition:@"aLumaPosition"
                                                         width:nextFrame.Y.stride
                                                        height:nextFrame.Y.lines];

        GLuint chromaPositionBuffer = [self setupTexturePosition:@"aChromaPosition"
                                                           width:nextFrame.Cb.stride * (format.lumaWidth / format.chromaWidth)
                                                          height:nextFrame.Cb.lines * (format.lumaHeight / format.chromaHeight)];

        // Note: moved texture attachment out of here
        
        glDrawArrays(GL_TRIANGLES, 0, rectanglePoints);
        [self debugCheck];
        
        glDeleteBuffers(1, &chromaPositionBuffer);
        [self debugCheck];
        glDeleteBuffers(1, &lumaPositionBuffer);
        [self debugCheck];
        glDeleteBuffers(1, &rectangleBuffer);
        [self debugCheck];
        
        // @todo destroy textures when tearing down, do we need to?
    }
    
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    // Make sure we update the screen after resize,
    // it doesn't seem to trigger otherwise.
    [self setNeedsDisplay];
}

#pragma mark OGVFrameView methods

// call me on the main thread
- (void)drawFrame:(OGVVideoBuffer *)buffer
{
    // Initialize GL context if we haven't already
    assert(self.context);
    [EAGLContext setCurrentContext:self.context];
    [self setupGLStuff];

    nextFrame = buffer;
    format = buffer.format;
    
    // Upload the textures now, they may not last
    // @todo don't keep the frame structure beyond this, just keep the dimension info
    [self attachTexture:@"uTextureY"
                    reg:GL_TEXTURE0
                  index:0
                  plane:nextFrame.Y];
    
    [self attachTexture:@"uTextureCb"
                    reg:GL_TEXTURE1
                  index:1
                  plane:nextFrame.Cb];
    
    [self attachTexture:@"uTextureCr"
                    reg:GL_TEXTURE2
                  index:2
                  plane:nextFrame.Cr];
    //[self drawRect:self.frame];
    [self setNeedsDisplay];
}

- (void)clearFrame
{
    nextFrame = nil;
    format = nil;
    [self setNeedsDisplay];
}

#pragma mark Private methods

-(void)setupGLStuff
{
    if (!program) {
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
    GLfloat frameAspect = (float)nextFrame.format.pictureWidth / (float)nextFrame.format.pictureHeight;
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

-(GLuint)setupTexturePosition:(NSString *)varname width:(int)texWidth height:(int)texHeight
{
    // Don't forget we're upside-down in OpenGL coordinate space
    GLfloat textureX0 = (float)nextFrame.format.pictureOffsetX / texWidth;
    GLfloat textureX1 = (float)(nextFrame.format.pictureOffsetX + nextFrame.format.pictureWidth) / texWidth;
    GLfloat textureY0 = (float)(nextFrame.format.pictureOffsetY + nextFrame.format.pictureHeight) / texHeight;
    GLfloat textureY1 = (float)nextFrame.format.pictureOffsetY / texHeight;
    const GLfloat textureRectangle[] = {
        textureX0, textureY0,
        textureX1, textureY0,
        textureX0, textureY1,
        textureX0, textureY1,
        textureX1, textureY0,
        textureX1, textureY1
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

-(GLuint)attachTexture:(NSString *)varname
                   reg:(GLenum)reg
                 index:(GLuint)index
                 plane:(OGVVideoPlane *)plane
{
    GLuint texture = textures[index];
    GLuint texWidth = plane.stride;
    GLuint texHeight = plane.lines;
    NSData *data = plane.data;
    
    if (texture != 0 && textureWidth[index] == texWidth && textureHeight[index] == texHeight) {
        // Reuse & update the existing texture
        texture = textures[index];

        glActiveTexture(reg);
        [self debugCheck];
        
        glTexSubImage2D(GL_TEXTURE_2D,
                        0, // mip level
                        0, // x
                        0, // y
                        texWidth,
                        texHeight,
                        GL_LUMINANCE, // format
                        GL_UNSIGNED_BYTE,
                        [data bytes]);
        [self debugCheck];

    } else {
        // Create a new texture!
        if (texture) {
            glDeleteTextures(1, &texture);
            [self debugCheck];
        }
        glGenTextures(1, &texture);
        [self debugCheck];
        textures[index] = texture;
        
        // Save the size for later
        textureWidth[index] = texWidth;
        textureHeight[index] = texHeight;
        
        glActiveTexture(reg);
        [self debugCheck];

        glBindTexture(GL_TEXTURE_2D, texture);
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

        glTexImage2D(GL_TEXTURE_2D,
                     0, // mip level
                     GL_LUMINANCE, // internal format
                     texWidth,
                     texHeight,
                     0, // border
                     GL_LUMINANCE, // format
                     GL_UNSIGNED_BYTE,
                     [data bytes]);
        [self debugCheck];
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
