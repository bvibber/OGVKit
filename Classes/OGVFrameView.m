//
//  OGVFrameView.m
//  OGVKit
//
//  Created by Brion on 11/6/13.
//  Copyright (c) 2013 Brion Vibber. All rights reserved.
//

#import <OGVKit/OGVKit.h>

@interface OGVFrameView (Private)
-(GLuint)setupTexturePosition:(NSString *)varname width:(int)texWidth height:(int)texHeight;
@end

static const char ogvFragmentShaderSource[] =
    "// inspired by https://github.com/mbebenita/Broadway/blob/master/Player/canvas.js\n"
    "\n"
    "precision mediump float;\n"
    "uniform sampler2D uTextureY;\n"
    "uniform sampler2D uTextureCb;\n"
    "uniform sampler2D uTextureCr;\n"
    "varying vec2 vLumaPosition;\n"
    "varying vec2 vChromaPosition;\n"
    "void main() {\n"
    "   // Y, Cb, and Cr planes are uploaded as LUMINANCE textures.\n"
    "   vec4 vY = texture2D(uTextureY, vLumaPosition);\n"
    "   vec4 vCb = texture2D(uTextureCb, vChromaPosition);\n"
    "   vec4 vCr = texture2D(uTextureCr, vChromaPosition);\n"
    "\n"
    "   // Now assemble that into a YUV vector, and premultipy the Y...\n"
    "   vec3 YUV = vec3(\n"
    "     vY.x * 1.1643828125,\n"
    "     vCb.x,\n"
    "     vCr.x\n"
    "   );\n"
    "   // And convert that to RGB!\n"
    "   gl_FragColor = vec4(\n"
    "     YUV.x + 1.59602734375 * YUV.z - 0.87078515625,\n"
    "     YUV.x - 0.39176171875 * YUV.y - 0.81296875 * YUV.z + 0.52959375,\n"
    "     YUV.x + 2.017234375   * YUV.y - 1.081390625,\n"
    "     1\n"
    "   );\n"
    "}\n";

static const char ogvVertexShaderSource[] =
    "attribute vec2 aPosition;\n"
    "attribute vec2 aLumaPosition;\n"
    "attribute vec2 aChromaPosition;\n"
    "varying vec2 vLumaPosition;\n"
    "varying vec2 vChromaPosition;\n"
    "void main() {\n"
    "    gl_Position = vec4(aPosition, 0, 1);\n"
    "    vLumaPosition = aLumaPosition;\n"
    "    vChromaPosition = aChromaPosition;\n"
    "}";

// In the world of GL there are no rectangles.
// There are only triangles.
// THERE IS NO SPOON.
static const GLuint rectanglePoints = 6;

@implementation OGVFrameView {
    OGVFrameBuffer *nextFrame;
    GLuint vertexShader;
    GLuint fragmentShader;
    GLuint program;
    GLuint textures[3];
    GLuint textureWidth[3];
    GLuint textureHeight[3];
}

#pragma mark GLKView method overrides

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        self.context = [self createGLContext];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        self.context = [self createGLContext];
    }
    return self;
}

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
                                                         width:nextFrame.strideY
                                                        height:nextFrame.frameHeight];
        GLuint chromaPositionBuffer = [self setupTexturePosition:@"aChromaPosition"
                                                           width:nextFrame.strideCb << nextFrame.hDecimation
                                                          height:nextFrame.frameHeight];

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

#pragma mark OGVFrameView methods

// call me on the main thread
- (void)drawFrame:(OGVFrameBuffer *)buffer
{
    // Initialize GL context if we haven't already
    [EAGLContext setCurrentContext:self.context];
    [self setupGLStuff];

    nextFrame = buffer;
    
    // Upload the textures now, they may not last
    // @todo don't keep the frame structure beyond this, just keep the dimension info
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
    //[self drawRect:self.frame];
    [self setNeedsDisplay];
}


#pragma mark Private methods

-(EAGLContext *)createGLContext
{
    EAGLContext *context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
    if (context == nil) {
        context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    }
    return context;
}

-(void)setupGLStuff
{
    if (!program) {
        vertexShader = [self compileShader:GL_VERTEX_SHADER fromCString:ogvVertexShaderSource];
        fragmentShader = [self compileShader:GL_FRAGMENT_SHADER fromCString:ogvFragmentShaderSource];
        
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

-(GLuint)compileShader:(GLenum)shaderType fromCString:(const char *)source
{
    GLuint shader = glCreateShader(shaderType);
    [self debugCheck];
    
    const GLchar *str = source;
    const GLint len = (GLint)strlen(source);
    glShaderSource(shader, 1, &str, &len);
    [self debugCheck];
    glCompileShader(shader);
    [self debugCheck];

    // todo: error handling? meh whatever
    
    return shader;
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
    GLfloat frameAspect = (float)nextFrame.pictureWidth / (float)nextFrame.pictureHeight;
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
    GLuint texture = textures[index];
    
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
        default: return @"Unknown error";
    }
}

@end
