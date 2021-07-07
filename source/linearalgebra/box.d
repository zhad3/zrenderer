module linearalgebra.box;

import std.math : abs, ceil, floor, round, fmin, fmax, isInfinity;

struct Box
{
    // We use int instead of float because the actual game engine does the same.
    // All kind of floats will be truncated to 0 (deliberately).
    int x1 = 0, y1 = 0;
    int x2 = 0, y2 = 0;

    uint width() const pure nothrow @safe @nogc
    {
        if (x1 == int.max || x2 == int.max || x1 == int.min || x2 == int.min)
        {
            return 0;
        }
        return cast(uint) (abs(x2 - x1));
    }

    uint height() const pure nothrow @safe @nogc
    {
        if (y1 == int.max || y2 == int.max || y1 == int.min || y2 == int.min)
        {
            return 0;
        }
        return cast(uint) (abs(y2 - y1));
    }

    Box toInfinity() pure nothrow @safe @nogc
    {
        this.x1 = int.max;
        this.y1 = int.max;
        this.x2 = int.min;
        this.y2 = int.min;

        return this;
    }

    bool isInfinite() const pure nothrow @safe @nogc
    {
        return (this.x1 == int.max || this.y1 == int.max ||
                this.x2 == int.min || this.y2 == int.min);
    }

    Box updateBounds(int x1, int y1, int x2, int y2) pure nothrow @safe @nogc
    {
        import std.algorithm : max, min;

        this.x1 = min(this.x1, min(x1, x2));
        this.y1 = min(this.y1, min(y1, y2));
        this.x2 = max(this.x2, max(x1, x2));
        this.y2 = max(this.y2, max(y1, y2));

        return this;
    }

    Box updateBounds(float x1, float y1, float x2, float y2) pure nothrow @safe @nogc
    {
        this.x1 = cast(int) (fmin(this.x1, fmin(x1, x2)));
        this.y1 = cast(int) (fmin(this.y1, fmin(y1, y2)));
        this.x2 = cast(int) (fmax(this.x2, fmax(x1, x2)));
        this.y2 = cast(int) (fmax(this.y2, fmax(y1, y2)));

        return this;
    }

    Box updateBounds(const scope Box box) pure nothrow @safe @nogc
    {
        return this.updateBounds(box.x1, box.y1, box.x2, box.y2);
    }

    import linearalgebra.vector : Vector2;

    Box updateBounds(const scope Vector2 pointA, const scope Vector2 pointB) pure nothrow @safe @nogc
    {
        return this.updateBounds(pointA.x, pointA.y, pointB.x, pointB.y);
    }
}
