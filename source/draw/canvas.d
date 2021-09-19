module draw.canvas;

struct Canvas
{
    uint width;
    uint height;
    int originx;
    int originy;
}

immutable(Canvas) canvasFromString(const scope string canvasArg) pure @safe
{
    if (canvasArg.length == 0)
    {
        return Canvas.init;
    }

    import std.regex : matchFirst;
    import std.conv : to;
    import validation : CanvasRegex;

    auto matchFound = matchFirst(canvasArg, CanvasRegex);

    return Canvas(
            matchFound[1].to!uint,
            matchFound[2].to!uint,
            matchFound[3].to!int,
            matchFound[4].to!int
    );
}
