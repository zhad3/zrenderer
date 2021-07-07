module draw.color;

struct Color
{
    uint color = 0x00000000;

    ubyte a() const pure nothrow @safe @nogc
    {
        return cast(ubyte)((this.color >> 24) & 0xFF);
    }

    void a(ubyte alpha) pure nothrow @safe @nogc
    {
        this.color = ((alpha << 24) & 0xFF000000) | (this.color & 0x00FFFFFF);
    }

    ubyte b() const pure nothrow @safe @nogc
    {
        return cast(ubyte)((this.color >> 16) & 0xFF);
    }

    void b(ubyte blue) pure nothrow @safe @nogc
    {
        this.color = ((blue << 16) & 0x00FF0000) | (this.color & 0xFF00FFFF);
    }

    ubyte g() const pure nothrow @safe @nogc
    {
        return cast(ubyte)((this.color >> 8) & 0xFF);
    }

    void g(ubyte green) pure nothrow @safe @nogc
    {
        this.color = ((green << 8) & 0x0000FF00) | (this.color & 0xFFFF00FF);
    }

    ubyte r() const pure nothrow @safe @nogc
    {
        return cast(ubyte)(this.color & 0xFF);
    }

    void r(ubyte red) pure nothrow @safe @nogc
    {
        this.color = (red & 0x000000FF) | (this.color & 0xFFFFFF00);
    }

    Color reverse() const pure nothrow @safe @nogc
    {
        import std.bitmanip : swapEndian;

        return cast(Color) this.color.swapEndian;
    }

    alias color this;
}

Color fromAABBGGRR(uint color) pure nothrow @safe @nogc
{
    Color newcolor;
    return newcolor;
}
