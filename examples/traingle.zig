const std = @import("std");
const gl = @import("gl");
const glfw = @cImport({
    @cInclude("GLFW/glfw3.h");
});

const VS_SOURCE: [*c]const u8 =
    \\#version 150
    \\in vec3 Pos;
    \\in vec3 Color;
    \\out vec3 in_fs_color;
    \\void main() {
    \\ gl_Position = vec4(Pos.xyz, 1.0);
    \\ in_fs_color = Color;
    \\}
;
const VS_SOURCE_LEN = @as(gl.GLint, @intCast(std.mem.len(VS_SOURCE)));
const FS_SOURCE: [*c]const u8 =
    \\#version 150
    \\in vec3 in_fs_color;
    \\out vec4 FragColor;
    \\void main() {
    \\ FragColor = vec4(in_fs_color, 1);
    \\}
;
const FS_SOURCE_LEN = @as(gl.GLint, @intCast(std.mem.len(FS_SOURCE)));

fn glfwErrCallback(_: c_int, error_msg: [*c]const u8) callconv(.C) void {
    std.log.err("[GLFW] {s} ", .{error_msg});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    _ = glfw.glfwSetErrorCallback(glfwErrCallback);

    if (glfw.glfwInit() == 0) {
        return error.GLFWInitFailed;
    }
    defer glfw.glfwTerminate();

    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MINOR, 2);

    const window = glfw.glfwCreateWindow(800, 600, "Hello", null, null);
    if (window == null) {
        return error.WindowCreationFailed;
    }
    defer glfw.glfwDestroyWindow(window);

    glfw.glfwMakeContextCurrent(window);
    gl.makeProcTableCurrent(try gl.loadGL(glfw.glfwGetProcAddress));

    var program: gl.GLuint = gl.glCreateProgram();
    {
        var vs: gl.GLuint = gl.glCreateShader(gl.GL_VERTEX_SHADER);
        defer gl.glDeleteShader(vs);

        var fs: gl.GLuint = gl.glCreateShader(gl.GL_FRAGMENT_SHADER);
        defer gl.glDeleteShader(fs);

        gl.glShaderSource(
            vs,
            1,
            &[_][*c]const u8{VS_SOURCE},
            &[_:0]gl.GLint{ VS_SOURCE_LEN, 0 },
        );
        gl.glShaderSource(
            fs,
            1,
            &[_][*c]const u8{FS_SOURCE},
            &[_:0]gl.GLint{ FS_SOURCE_LEN, 0 },
        );
        gl.glCompileShader(vs);
        gl.glCompileShader(fs);

        var status: gl.GLuint = 0;
        gl.glGetShaderiv(vs, gl.GL_COMPILE_STATUS, @ptrCast(&status));
        if (status == 0) {
            var infolog_len: gl.GLint = 0;
            gl.glGetShaderiv(vs, gl.GL_INFO_LOG_LENGTH, @ptrCast(&infolog_len));

            var buffer = try allocator.alloc(u8, @intCast(infolog_len));
            defer allocator.free(buffer);

            gl.glGetShaderInfoLog(vs, infolog_len, null, buffer.ptr);
            std.log.err("[GL] Vertex shader compilation failed:\n{s}", .{buffer});
            return error.ShaderCompilationFailed;
        }

        gl.glGetShaderiv(fs, gl.GL_COMPILE_STATUS, @ptrCast(&status));
        if (status == 0) {
            var infolog_len: gl.GLint = 0;
            gl.glGetShaderiv(fs, gl.GL_INFO_LOG_LENGTH, @ptrCast(&infolog_len));

            var buffer = try allocator.alloc(u8, @intCast(infolog_len));
            defer allocator.free(buffer);

            gl.glGetShaderInfoLog(fs, infolog_len, null, buffer.ptr);
            std.log.err("[GL] Fragment shader compilation failed:\n{s}", .{buffer});
            return error.ShaderCompilationFailed;
        }

        gl.glAttachShader(program, vs);
        gl.glAttachShader(program, fs);

        gl.glBindAttribLocation(program, 0, "Pos");
        gl.glBindAttribLocation(program, 1, "Color");
        gl.glLinkProgram(program);

        gl.glGetProgramiv(program, gl.GL_LINK_STATUS, @ptrCast(&status));
        if (status == 0) {
            var infolog_len: gl.GLint = 0;
            gl.glGetProgramiv(program, gl.GL_INFO_LOG_LENGTH, @ptrCast(&infolog_len));

            var buffer = try allocator.alloc(u8, @intCast(infolog_len));
            defer allocator.free(buffer);

            gl.glGetProgramInfoLog(program, infolog_len, null, buffer.ptr);
            std.log.err("[GL] Program linking failed!\n{s}", .{buffer});
            return error.ProgramLinkingFailed;
        }
        gl.glDetachShader(program, vs);
        gl.glDetachShader(program, fs);
    }

    const verticies = [_]f32{
        -0.5, -0.5, 0.0, 0.0, 0.0, 1.0,
        0.5,  -0.5, 0.0, 0.0, 1.0, 0.0,
        0.0,  0.5,  0.0, 1.0, 0.0, 0.0,
    };
    // const indecies = [_]gl.GLuint{ 0, 1, 2 };

    var vao: gl.GLuint = 0;
    var vbo: gl.GLuint = 0;
    gl.glGenVertexArrays(1, &vao);
    gl.glBindVertexArray(vao);

    gl.glGenBuffers(1, &vbo);
    gl.glBindBuffer(gl.GL_ARRAY_BUFFER, vbo);
    gl.glBufferData(gl.GL_ARRAY_BUFFER, @sizeOf(f32) * verticies.len, @ptrCast(&verticies), gl.GL_STATIC_DRAW);

    gl.glEnableVertexAttribArray(0);
    gl.glVertexAttribPointer(0, 3, gl.GL_FLOAT, gl.GL_FALSE, @sizeOf(f32) * 3, null);

    gl.glEnableVertexAttribArray(1);
    gl.glVertexAttribPointer(1, 3, gl.GL_FLOAT, gl.GL_FALSE, @sizeOf(f32) * 3, @ptrFromInt(@sizeOf(f32) * 3));

    gl.glUseProgram(program);
    gl.glClearColor(0.0, 0.0, 0.0, 1.0);
    while (glfw.glfwWindowShouldClose(window) == 0) {
        glfw.glfwPollEvents();
        gl.glClear(@bitCast(gl.GL_COLOR_BUFFER_BIT));
        gl.glDrawArrays(gl.GL_TRIANGLES, 0, 3);
        // gl.glDrawElements(gl.GL_TRIANGLES, 3, gl.GL_UNSIGNED_INT, &indecies);

        glfw.glfwSwapBuffers(window);
    }
}
