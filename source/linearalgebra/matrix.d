module linearalgebra.matrix;

import std.traits : isNumeric;

struct Matrix2
{
    float m11, m12;
    float m21, m22;

    this(float m11, float m12, float m21, float m22) pure nothrow @safe @nogc
    {
        this.m11 = m11;
        this.m12 = m12;
        this.m21 = m21;
        this.m22 = m22;
    }

    Matrix2 opUnary(string op)() const pure nothrow @safe @nogc
    {
        return mixin(
                "Matrix2(" ~
                op ~ "this.m11, " ~ op ~ "this.m12," ~
                op ~ "this.m21, " ~ op ~ "this.m22" ~
                ")");
    }

    unittest
    {
        auto matrix = Matrix2(1, 2, 3, 4);

        assert(-matrix == Matrix2(-1, -2, -3, -4));
    }

    Matrix2 opBinary(string op, R)(const scope R rhs) const pure nothrow @safe @nogc
            if (isNumeric!R && (op == "*" || op == "/"))
    {
        return mixin(
                "Matrix2(" ~
                "this.m11 " ~ op ~ " rhs, this.m12 " ~ op ~ " rhs," ~
                "this.m21 " ~ op ~ " rhs, this.m22 " ~ op ~ " rhs" ~
                ")");
    }

    unittest
    {
        auto matrix = Matrix2(1, 2, 4, 8);

        assert(matrix * 6 == Matrix2(6, 12, 24, 48));
        assert(matrix / 2 == Matrix2(0.5, 1, 2, 4));
    }

    Matrix2 opBinaryRight(string op, R)(const scope R lhs) const pure nothrow @safe @nogc
            if (isNumeric!R && (op == "*"))
    {
        return this.opBinary!(op, R)(lhs);
    }

    Matrix2 opBinary(string op)(const scope Matrix2 rhs) const pure nothrow @safe @nogc
            if (op == "*")
    {
        return Matrix2(
                this.m11 * rhs.m11 + this.m12 * rhs.m21,
                this.m11 * rhs.m12 + this.m12 * rhs.m22,
                this.m21 * rhs.m11 + this.m22 * rhs.m21,
                this.m21 * rhs.m12 + this.m22 * rhs.m22);
    }

    unittest
    {
        auto matrixA = Matrix2(1, 2, 3, 4);
        auto matrixB = Matrix2(5, 6, 7, 8);

        assert(matrixA * matrixB == Matrix2(19, 22, 43, 50));
        assert(matrixB * matrixA == Matrix2(23, 34, 31, 46));
    }

    Matrix2 opOpAssign(string op, R)(const scope R rhs) pure nothrow @safe @nogc
            if (isNumeric!R && (op == "*" || op == "/"))
    {
        return mixin("this " ~ op ~ " rhs");
    }

    Matrix2 opOpAssign(string op)(const scope Matrix2 rhs) pure nothrow @safe @nogc
            if (op == "*")
    {
        return mixin("this " ~ op ~ " rhs");
    }
}

struct Matrix3
{
    float m11, m12, m13;
    float m21, m22, m23;
    float m31, m32, m33;

    this(float m11, float m12, float m13,
            float m21, float m22, float m23,
            float m31, float m32, float m33) pure nothrow @safe @nogc
    {
        this.m11 = m11;
        this.m12 = m12;
        this.m13 = m13;
        this.m21 = m21;
        this.m22 = m22;
        this.m23 = m23;
        this.m31 = m31;
        this.m32 = m32;
        this.m33 = m33;
    }

    Matrix3 opUnary(string op)() const pure nothrow @safe @nogc
    {
        return mixin(
                "Matrix3(" ~
                op ~ "this.m11, " ~ op ~ "this.m12, " ~ op ~ "this.m13, " ~
                op ~ "this.m21, " ~ op ~ "this.m22, " ~ op ~ "this.m23, " ~
                op ~ "this.m31, " ~ op ~ "this.m32, " ~ op ~ "this.m33" ~
                ")");
    }

    unittest
    {
        auto matrix = Matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9);

        assert(-matrix == Matrix3(-1, -2, -3, -4, -5, -6, -7, -8, -9));
    }

    Matrix3 opBinary(string op, R)(const scope R rhs) const pure nothrow @safe @nogc
            if (isNumeric!R && (op == "*" || op == "/"))
    {
        return mixin(
                "Matrix3(" ~
                "this.m11 " ~ op ~ " rhs, this.m12 " ~ op ~ " rhs, this.m13 " ~ op ~ " rhs," ~
                "this.m21 " ~ op ~ " rhs, this.m22 " ~ op ~ " rhs, this.m23 " ~ op ~ " rhs," ~
                "this.m31 " ~ op ~ " rhs, this.m32 " ~ op ~ " rhs, this.m33 " ~ op ~ " rhs" ~
                ")");
    }

    unittest
    {
        auto matrix = Matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9);

        assert(matrix * 6 == Matrix3(6, 12, 18, 24, 30, 36, 42, 48, 54));
        assert(matrix / 2 == Matrix3(0.5, 1, 1.5, 2, 2.5, 3, 3.5, 4, 4.5));
    }

    Matrix3 opBinaryRight(string op, R)(const scope R lhs) const pure nothrow @safe @nogc
            if (isNumeric!R && (op == "*"))
    {
        return this.opBinary!(op, R)(lhs);
    }

    Matrix3 opBinary(string op)(const scope Matrix3 rhs) const pure nothrow @safe @nogc
            if (op == "*")
    {
        return Matrix3(
                this.m11 * rhs.m11 + this.m12 * rhs.m21 + this.m13 * rhs.m31,
                this.m11 * rhs.m12 + this.m12 * rhs.m22 + this.m13 * rhs.m32,
                this.m11 * rhs.m13 + this.m12 * rhs.m23 + this.m13 * rhs.m33,
                this.m21 * rhs.m11 + this.m22 * rhs.m21 + this.m23 * rhs.m31,
                this.m21 * rhs.m12 + this.m22 * rhs.m22 + this.m23 * rhs.m32,
                this.m21 * rhs.m13 + this.m22 * rhs.m23 + this.m23 * rhs.m33,
                this.m31 * rhs.m11 + this.m32 * rhs.m21 + this.m33 * rhs.m31,
                this.m31 * rhs.m12 + this.m32 * rhs.m22 + this.m33 * rhs.m32,
                this.m31 * rhs.m13 + this.m32 * rhs.m23 + this.m33 * rhs.m33);
    }

    unittest
    {
        auto matrixA = Matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9);
        auto matrixB = Matrix3(9, 8, 7, 6, 5, 4, 3, 2, 1);

        assert(matrixA * matrixB == Matrix3(30, 24, 18, 84, 69, 54, 138, 114, 90));
        assert(matrixB * matrixA == Matrix3(90, 114, 138, 54, 69, 84, 18, 24, 30));
    }

    Matrix3 opOpAssign(string op, R)(const scope R rhs) pure nothrow @safe @nogc
            if (isNumeric!R && (op == "*" || op == "/"))
    {
        return mixin("this " ~ op ~ " rhs");
    }

    Matrix3 opOpAssign(string op)(const scope Matrix3 rhs) pure nothrow @safe @nogc
            if (op == "*")
    {
        return mixin("this " ~ op ~ " rhs");
    }
}
