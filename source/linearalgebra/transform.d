module linearalgebra.transform;

import linearalgebra.vector;
import linearalgebra.matrix;
import std.math : PI;

enum PI_180 = PI / 180f;

struct TransformMatrix
{
    Vector2 size = Vector2(0, 0);
    Vector2 origin = Vector2(0, 0);
    Vector2 translation = Vector2(0, 0);
    Vector2 scaling = Vector2(1, 1);
    float rotation = 0f;
    Matrix3 transformation = identityMatrix();

    void setSize(float x, float y) pure nothrow @safe @nogc
    {
        this.size.x = x;
        this.size.y = y;
    }

    void setOrigin(float x, float y) pure nothrow @safe @nogc
    {
        this.origin.x = x;
        this.origin.y = y;
    }

    void translate(float x, float y) pure nothrow @safe @nogc
    {
        this.translation.x = x;
        this.translation.y = y;
    }

    void scale(float x, float y) pure nothrow @safe @nogc
    {
        this.scaling.x = x;
        this.scaling.y = y;
    }

    void rotate(float radians) pure nothrow @safe @nogc
    {
        this.rotation = radians;
    }

    Matrix3 calculate() nothrow @safe @nogc
    {
        import linearalgebra.operations : truncate, apply;
        import std.math : round;

        Matrix3 transformationMatrix = identityMatrix();
        transformationMatrix = transformationMatrix * translationMatrix(this.translation);
        transformationMatrix = transformationMatrix * rotationMatrix(this.rotation);
        transformationMatrix = transformationMatrix * scaleMatrix(this.scaling);
        transformationMatrix = transformationMatrix * translationMatrix((-this.size * this.origin).apply!round);

        this.transformation = transformationMatrix;

        return this.transformation;
    }
    unittest
    {
        TransformMatrix t;
        t.setOrigin(0.5, 0.5);
        t.setSize(10, 10);
        t.translate(5, 5);
        t.scale(2, 2);
        t.rotate(PI/2f);

        t.calculate();

        import linearalgebra.operations : inverse;

        assert(t * t.inverse == identityMatrix());

        Vector3 p = Vector3(10, 5, 1);
        Vector3 p2 = t * p;

        import std.stdio : writeln;

        writeln(p2);
        writeln(t.inverse * p2, p);

        assert(t.inverse * p2 == p);
    }

    alias transformation this;
}

Matrix3 identityMatrix() pure nothrow @safe @nogc
{
    return Matrix3(
            1, 0, 0,
            0, 1, 0,
            0, 0, 1);
}

Matrix3 translationMatrix(float x = 0, float y = 0) pure nothrow @safe @nogc
{
    return Matrix3(
            1, 0, x,
            0, 1, y,
            0, 0, 1);
}

Matrix3 translationMatrix(const scope Vector2 vector) pure nothrow @safe @nogc
{
    return Matrix3(
            1, 0, vector.x,
            0, 1, vector.y,
            0, 0, 1);
}

Matrix3 scaleMatrix(float x = 1, float y = 1) pure nothrow @safe @nogc
{
    return Matrix3(
            x, 0, 0,
            0, y, 0,
            0, 0, 1);
}

Matrix3 scaleMatrix(const scope Vector2 vector) pure nothrow @safe @nogc
{
    return Matrix3(
            vector.x, 0, 0,
            0, vector.y, 0,
            0, 0, 1);
}

Matrix3 rotationMatrix(float radians = 0) pure nothrow @safe @nogc
{
    import std.math : sin, cos;

    return Matrix3(
            cos(radians), -sin(radians), 0,
            sin(radians), cos(radians), 0,
            0, 0, 1);
}
