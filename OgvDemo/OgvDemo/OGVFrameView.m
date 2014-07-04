//
//  OGVFrameView.m
//  OgvDemo
//
//  Created by Brion on 11/6/13.
//  Copyright (c) 2013 Brion Vibber. All rights reserved.
//

#import "OGVFrameView.h"

@interface OGVFrameView (Private)
-(GLuint)setupTexturePosition:(NSString *)varname width:(int)texWidth height:(int)texHeight;
@end

// In the world of GL there are no rectangles.
// There are only triangles.
// THERE IS NO SPOON.
static const GLuint rectanglePoints = 6;
static GLfloat rectangle[] = {
    // First triangle (top left, clockwise)
    -1.0, -1.0,
    +1.0, -1.0,
    -1.0, +1.0,
    
    // Second triangle (bottom right, clockwise)
    -1.0, +1.0,
    +1.0, -1.0,
    +1.0, +1.0
};

@implementation OGVFrameView {
    OGVFrameBuffer *nextFrame;
    GLuint vertexShader;
    GLuint fragmentShader;
    GLuint program;
    GLuint textures[3];
    
}

#pragma mark GLKView method overrides

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)drawRect:(CGRect)rect
{
    glClearColor(0, 0, 0, 1);
    [self debugCheck];

    glDepthMask(GL_TRUE); // voodoo from http://stackoverflow.com/questions/5470822/ios-opengl-es-logical-buffer-loads
    glClear(GL_DEPTH_BUFFER_BIT | GL_COLOR_BUFFER_BIT);
    [self debugCheck];

    if (!program) {
        [self setupGLStuff];
    }
    
    if (nextFrame) {
        // Set up our rectangle as a buffer...
        GLuint rectangleBuffer;
        glGenBuffers(1, &rectangleBuffer);
        [self debugCheck];

        glBindBuffer(GL_ARRAY_BUFFER, rectangleBuffer);
        [self debugCheck];

        glBufferData(GL_ARRAY_BUFFER, rectanglePoints * sizeof(GLfloat) * 2, rectangle, GL_STATIC_DRAW);
        [self debugCheck];
        
        // Assign the rectangle to the position input on the vertex shader
        GLuint positionLocation = glGetAttribLocation(program, "aPosition");
        [self debugCheck];

        glEnableVertexAttribArray(positionLocation);
        [self debugCheck];

        glVertexAttribPointer(positionLocation, 2, GL_FLOAT, false, 0, 0);
        [self debugCheck];
        
        
        GLuint lumaPositionBuffer = [self setupTexturePosition:@"aLumaPosition"
                                                         width:nextFrame.strideY
                                                        height:nextFrame.frameHeight];
        GLuint chromaPositionBuffer = [self setupTexturePosition:@"aChromaPosition"
                                                           width:nextFrame.strideCb << nextFrame.hDecimation
                                                          height:nextFrame.frameHeight];
        
        [self attachTexture:@"uTextureY"
                        reg:GL_TEXTURE0
                      index:0
                      width:nextFrame.strideY
                     height:nextFrame.frameHeight
                       data:nextFrame.dataY];

        [self attachTexture:@"uTextureCb"
                        reg:GL_TEXTURE1
                      index:1
                      width:nextFrame.strideCb
                     height:nextFrame.frameHeight >> nextFrame.vDecimation
                       data:nextFrame.dataCb];

        [self attachTexture:@"uTextureCr"
                        reg:GL_TEXTURE2
                      index:2
                      width:nextFrame.strideCr
                     height:nextFrame.frameHeight >> nextFrame.vDecimation
                       data:nextFrame.dataCr];
        
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

#pragma mark OGVFrameView methods

- (void)drawFrame:(OGVFrameBuffer *)buffer
{
    if (!self.context) {
        self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
        [EAGLContext setCurrentContext:self.context];
    }

    nextFrame = buffer;
    //[self drawRect:self.frame];
    [self setNeedsDisplay];
}


#pragma mark Private methods

-(void)setupGLStuff
{
    vertexShader = [self compileShader:GL_VERTEX_SHADER fromFile:@"YCbCr-vertex"];
    fragmentShader = [self compileShader:GL_FRAGMENT_SHADER fromFile:@"YCbCr-fragment"];
    
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

-(GLuint)compileShader:(GLenum)shaderType fromFile:(NSString *)filename
{
    NSString *path = [[NSBundle mainBundle] pathForResource:filename ofType:@"glsl"];
    NSData *data = [NSData dataWithContentsOfFile:path];
    GLuint shader = glCreateShader(shaderType);
    [self debugCheck];
    
    const GLchar *str = [data bytes];
    const GLint len = (GLint)[data length];
    glShaderSource(shader, 1, &str, &len);
    [self debugCheck];
    glCompileShader(shader);
    [self debugCheck];

    // todo: error handling? meh whatever
    
    return shader;
}

-(GLuint)setupTexturePosition:(NSString *)varname width:(int)texWidth height:(int)texHeight
{
    // Don't forget we're upside-down in OpenGL coordinate space
    GLfloat textureX0 = (float)nextFrame.pictureOffsetX / texWidth;
    GLfloat textureX1 = (float)(nextFrame.pictureOffsetX + nextFrame.pictureWidth) / texWidth;
    GLfloat textureY0 = (float)(nextFrame.pictureOffsetY + nextFrame.pictureHeight) / texHeight;
    GLfloat textureY1 = (float)nextFrame.pictureOffsetY / texHeight;
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
                 width:(GLuint)texWidth
                height:(GLuint)texHeight
                  data:(NSData *)data
{
    GLuint texture;
    
    if (textures[index] != 0) {
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
        glGenTextures(1, &texture);
        [self debugCheck];
        textures[index] = texture;
        
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
    if (NO) {
        GLenum err = glGetError();
        if (err != GL_NO_ERROR) {
            NSString *str = [self stringForGLError:err];
            NSLog(@"GL error: %d %@", (int)err, str);
            @throw [NSException exceptionWithName:@"OGVFrameViewException"
                                           reason:str
                                         userInfo:@{@"glError": @((int)err),
                                                    @"glErrorString": str}];
        }
    }
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
        case GL_STACK_UNDERFLOW: return @"GL_STACK_UNDERFLOW";
        case GL_STACK_OVERFLOW: return @"GL_STACK_OVERFLOW";
        default: return @"Unknown error";
    }
}

@end
