module linearalgebra.vector;

import std.traits : isNumeric;
import linearalgebra.matrix;

struct Vector2
{
    float x = 0, y = 0;

    this(float x, float y) pure nothrow @safe @nogc
    {
        this.x = x;
        this.y = y;
    }

    Vector2 opUnary(string op)() const pure nothrow @safe @nogc
    {
        return mixin("Vector2(" ~ op ~ "this.x, " ~ op ~ "this.y)");
    }

    unittest
    {
        auto vector = Vector2(1, 2);
        assert(-vector == Vector2(-1, -2));
    }

    Vector2 opBinary(string op, R)(const scope R rhs) const pure nothrow @safe @nogc
            if (isNumeric!R)
    {
        return mixin("Vector2(this.x " ~ op ~ " rhs, this.y " ~ op ~ " rhs)");
    }

    unittest
    {
        auto vectorA = Vector2(2, 3);
        auto scalar = 6;

        assert(vectorA + scalar == Vector2(8, 9));
        assert(vectorA - scalar == Vector2(-4, -3));
        assert(vectorA * scalar == Vector2(12, 18));
        assert(vectorA / scalar == Vector2(1 / 3f, 0.5));
    }

    Vector2 opBinaryRight(string op, R)(const scope R lhs) const pure nothrow @safe @nogc
            if (isNumeric!R && (op == "*" || op == "+"))
    {
        return this.opBinary!(op, R)(lhs);
    }

    unittest
    {
        auto vector = Vector2(2, 3);

        assert(6 * vector == Vector2(12, 18));
        assert(2 + vector == Vector2(4, 5));
    }

    Vector2 opBinary(string op)(const scope Vector2 rhs) const pure nothrow @safe @nogc
    {
        return mixin("Vector2(this.x " ~ op ~ " rhs.x, this.y " ~ op ~ " rhs.y)");
    }

    unittest
    {
        auto vectorA = Vector2(2, 3);
        auto vectorB = Vector2(6, 2);

        assert(vectorA + vectorB == Vector2(8, 5));
        assert(vectorA - vectorB == Vector2(-4, 1));
        assert(vectorA * vectorB == Vector2(12, 6));
        assert(vectorA / vectorB == Vector2(1 / 3f, 1.5));
        assert(vectorB / vectorA == Vector2(3, 2 / 3f));
    }

    Vector2 opBinary(string op)(const scope Matrix2 rhs) const pure nothrow @safe @nogc
            if (op == "*")
    {
        return Vector2(this.x * rhs.m11 + this.y * rhs.m21, this.x * rhs.m12 + this.y * rhs.m22);
    }

    unittest
    {
        auto vector = Vector2(1, 2);
        auto matrix = Matrix2(1, 2, 3, 4);

        assert(vector * matrix == Vector2(7, 10));
    }

    Vector2 opBinaryRight(string op)(const scope Matrix2 lhs) const pure nothrow @safe @nogc
            if (op == "*")
    {
        return Vector2(lhs.m11 * this.x + lhs.m12 * y, lhs.m21 * this.x + lhs.m22 * this.y);
    }

    unittest
    {
        auto vector = Vector2(1, 2);
        auto matrix = Matrix2(1, 2, 3, 4);

        assert(matrix * vector == Vector2(5, 11));
    }

    Vector2 opOpAssign(string op, R)(const scope R rhs) pure nothrow @safe @nogc
            if (isNumeric!R)
    {
        return mixin("this " ~ op ~ " rhs");
    }

    Vector2 opOpAssign(string op)(const scope Vector2 rhs) pure nothrow @safe @nogc
    {
        return mixin("this " ~ op ~ " rhs");
    }

    Vector2 opOpAssign(string op)(const scope Matrix2 rhs) pure nothrow @safe @nogc
            if (op == "*")
    {
        return mixin("this " ~ op ~ " rhs");
    }
}

struct Vector3
{
    float x = 0, y = 0, z = 0;

    this(float x, float y, float z) pure nothrow @safe @nogc
    {
        this.x = x;
        this.y = y;
        this.z = z;
    }

    Vector3 opUnary(string op)() const pure nothrow @safe @nogc
    {
        return mixin("Vector3(" ~ op ~ "this.x, " ~ op ~ "this.y, " ~ op ~ "this.z)");
    }

    unittest
    {
        auto vector = Vector3(1, 2, 3);
        assert(-vector == Vector3(-1, -2, -3));
    }

    Vector3 opBinary(string op, R)(const scope R rhs) const pure nothrow @safe @nogc
            if (isNumeric!R)
    {
        return mixin("Vector3(this.x " ~ op ~ " rhs, this.y " ~ op ~ " rhs, this.z " ~ op ~ " rhs)");
    }

    unittest
    {
        auto vectorA = Vector3(2, 3, 4);
        auto scalar = 6;

        assert(vectorA + scalar == Vector3(8, 9, 10));
        assert(vectorA - scalar == Vector3(-4, -3, -2));
        assert(vectorA * scalar == Vector3(12, 18, 24));
        assert(vectorA / scalar == Vector3(1 / 3f, 0.5, 2 / 3f));
    }

    Vector3 opBinaryRight(string op, R)(const scope R lhs) const pure nothrow @safe @nogc
            if (isNumeric!R && (op == "*" || op == "+"))
    {
        return this.opBinary!(op, R)(lhs);
    }

    unittest
    {
        auto vector = Vector3(2, 3, 4);

        assert(6 * vector == Vector3(12, 18, 24));
        assert(2 + vector == Vector3(4, 5, 6));
    }

    Vector3 opBinary(string op)(const scope Vector3 rhs) const pure nothrow @safe @nogc
    {
        return mixin("Vector3(this.x " ~ op ~ " rhs.x, this.y " ~ op ~ " rhs.y, this.z " ~ op ~ " rhs.z)");
    }

    unittest
    {
        auto vectorA = Vector3(2, 3, 4);
        auto vectorB = Vector3(6, 2, 4);

        assert(vectorA + vectorB == Vector3(8, 5, 8));
        assert(vectorA - vectorB == Vector3(-4, 1, 0));
        assert(vectorA * vectorB == Vector3(12, 6, 16));
        assert(vectorA / vectorB == Vector3(1 / 3f, 1.5, 1));
        assert(vectorB / vectorA == Vector3(3, 2 / 3f, 1));
    }

    Vector3 opBinary(string op)(const scope Matrix3 rhs) const pure nothrow @safe @nogc
            if (op == "*")
    {
        return Vector3(
                this.x * rhs.m11 + this.y * rhs.m21 + this.z * rhs.m31,
                this.x * rhs.m12 + this.y * rhs.m22 + this.z * rhs.m32,
                this.x * rhs.m13 + this.y * rhs.m23 + this.z * rhs.m33);
    }

    unittest
    {
        auto vector = Vector3(1, 2, 3);
        auto matrix = Matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9);

        assert(vector * matrix == Vector3(30, 36, 42));
    }

    Vector3 opBinaryRight(string op)(const scope Matrix3 lhs) const pure nothrow @safe @nogc
            if (op == "*")
    {
        return Vector3(
                lhs.m11 * this.x + lhs.m12 * this.y + lhs.m13 * this.z,
                lhs.m21 * this.x + lhs.m22 * this.y + lhs.m23 * this.z,
                lhs.m31 * this.x + lhs.m32 * this.y + lhs.m33 * this.z);
    }

    unittest
    {
        auto vector = Vector3(1, 2, 3);
        auto matrix = Matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9);

        assert(matrix * vector == Vector3(14, 32, 50));
    }

    Vector3 opOpAssign(string op, R)(const scope R rhs) pure nothrow @safe @nogc
            if (isNumeric!R)
    {
        return mixin("this " ~ op ~ " rhs");
    }

    Vector3 opOpAssign(string op)(const scope Vector3 rhs) pure nothrow @safe @nogc
    {
        return mixin("this " ~ op ~ " rhs");
    }

    Vector3 opOpAssign(string op)(const scope Matrix3 rhs) pure nothrow @safe @nogc
            if (op == "*")
    {
        return mixin("this " ~ op ~ " rhs");
    }
}
