module linearalgebra.operations;

import linearalgebra.vector;
import linearalgebra.matrix;

ref Vector2 set(return ref Vector2 vector, float x, float y) pure nothrow @safe @nogc
{
    vector.x = x;
    vector.y = y;
    return vector;
}
///
unittest
{
    auto vector = Vector2(0, 0);
    vector.set(1, 2);

    assert(vector == Vector2(1, 2));
}

ref Vector3 set(return ref Vector3 vector, float x, float y, float z) pure nothrow @safe @nogc
{
    vector.x = x;
    vector.y = y;
    vector.z = z;
    return vector;
}
///
unittest
{
    auto vector = Vector3(0, 0, 0);
    vector.set(1, 2, 3);

    assert(vector == Vector3(1, 2, 3));
}

ref Matrix2 set(return ref Matrix2 matrix, float m11, float m12, float m21, float m22) pure nothrow @safe @nogc
{
    matrix.m11 = m11;
    matrix.m12 = m12;
    matrix.m21 = m21;
    matrix.m22 = m22;
    return matrix;
}
///
unittest
{
    auto matrix = Matrix2(0, 0, 0, 0);
    matrix.set(1, 2, 3, 4);

    assert(matrix == Matrix2(1, 2, 3, 4));
}

ref Matrix2 setRow(uint row)(return ref Matrix2 matrix, float x, float y) pure nothrow @safe @nogc
        if (row < 2)
{
    import std.format : format;

    mixin(format("matrix.m%d1 = x;", row + 1));
    mixin(format("matrix.m%d2 = y;", row + 1));

    return matrix;
}
///
unittest
{
    auto matrix = Matrix2(0, 0, 0, 0);
    matrix.setRow!1(1, 2);
    assert(matrix == Matrix2(0, 0, 1, 2));

    matrix.setRow!0(3, 4);
    assert(matrix == Matrix2(3, 4, 1, 2));
}

ref Matrix2 setCol(uint col)(return ref Matrix2 matrix, float x, float y) pure nothrow @safe @nogc
        if (col < 2)
{
    import std.format : format;

    mixin(format("matrix.m1%d = x;", col + 1));
    mixin(format("matrix.m2%d = y;", col + 1));

    return matrix;
}
///
unittest
{
    auto matrix = Matrix2(0, 0, 0, 0);
    matrix.setCol!1(1, 2);
    assert(matrix == Matrix2(0, 1, 0, 2));

    matrix.setCol!0(3, 4);
    assert(matrix == Matrix2(3, 1, 4, 2));
}

float determinant(const scope Matrix2 matrix) pure nothrow @safe @nogc
{
    return matrix.m11 * matrix.m22 - matrix.m21 * matrix.m12;
}
///
unittest
{
    auto matrix = Matrix2(1, 2, 3, 4);

    assert(matrix.determinant == -2);
}

Matrix2 inverse(const scope Matrix2 matrix) pure @safe @nogc
{
    auto det = matrix.determinant;

    import std.math : isClose;

    if (isClose(det, 0f))
    {
        det = float.epsilon;
    }

    return (1 / det) * Matrix2(matrix.m22, -matrix.m12, -matrix.m21, matrix.m11);
}
///
unittest
{
    auto matrix = Matrix2(1, 2, 3, 4);
    auto inverseMatrix = Matrix2(-2, 1, 3/2f, -0.5);

    assert(matrix.inverse == inverseMatrix);
    assert(inverseMatrix * matrix == Matrix2(1, 0, 0, 1));
}

void invert(out Matrix2 matrix) pure @safe
{
    matrix = matrix.inverse;
}

ref Matrix3 set(return ref Matrix3 matrix,
        float m11, float m12, float m13,
        float m21, float m22, float m23,
        float m31, float m32, float m33) pure nothrow @safe @nogc
{
    matrix.m11 = m11;
    matrix.m12 = m12;
    matrix.m13 = m13;
    matrix.m21 = m21;
    matrix.m22 = m22;
    matrix.m23 = m23;
    matrix.m31 = m31;
    matrix.m32 = m32;
    matrix.m33 = m33;
    return matrix;
}
///
unittest
{
    auto matrix = Matrix3(0, 0, 0, 0, 0, 0, 0, 0, 0);
    matrix.set(1, 2, 3, 4, 5, 6, 7, 8, 9);

    assert(matrix == Matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9));
}

ref Matrix3 setRow(uint row)(return ref Matrix3 matrix, float x, float y, float z) pure nothrow @safe @nogc
        if (row < 3)
{
    import std.format : format;

    mixin(format("matrix.m%d1 = x;", row + 1));
    mixin(format("matrix.m%d2 = y;", row + 1));
    mixin(format("matrix.m%d3 = z;", row + 1));

    return matrix;
}
///
unittest
{
    auto matrix = Matrix3(0, 0, 0, 0, 0, 0, 0, 0, 0);
    matrix.setRow!1(1, 2, 3);
    assert(matrix == Matrix3(0, 0, 0, 1, 2, 3, 0, 0, 0));

    matrix.setRow!0(3, 4, 5);
    assert(matrix == Matrix3(3, 4, 5, 1, 2, 3, 0, 0, 0));
}

ref Matrix3 setCol(uint col)(return ref Matrix3 matrix, float x, float y, float z) pure nothrow @safe @nogc
        if (col < 3)
{
    import std.format : format;

    mixin(format("matrix.m1%d = x;", col + 1));
    mixin(format("matrix.m2%d = y;", col + 1));
    mixin(format("matrix.m3%d = z;", col + 1));

    return matrix;
}
///
unittest
{
    auto matrix = Matrix3(0, 0, 0, 0, 0, 0, 0, 0, 0);
    matrix.setCol!1(1, 2, 3);
    assert(matrix == Matrix3(0, 1, 0, 0, 2, 0, 0, 3, 0));

    matrix.setCol!0(3, 4, 5);
    assert(matrix == Matrix3(3, 1, 0, 4, 2, 0, 5, 3, 0));
}

float determinant(const scope Matrix3 matrix) pure nothrow @safe @nogc
{
    return matrix.m11 * matrix.m22 * matrix.m33 +
        matrix.m12 * matrix.m23 * matrix.m31 +
        matrix.m13 * matrix.m21 * matrix.m32 -
        matrix.m31 * matrix.m22 * matrix.m13 -
        matrix.m32 * matrix.m23 * matrix.m11 -
        matrix.m33 * matrix.m21 * matrix.m12;
}
///
unittest
{
    auto matrix = Matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9);

    assert(matrix.determinant == 0);
}

Matrix3 inverse(const scope Matrix3 matrix) pure @safe @nogc
{
    auto det = matrix.determinant;

    import std.math : isClose;

    if (isClose(det, 0f))
    {
        det = float.epsilon;
    }

    return (1 / det) * Matrix3(
            matrix.m22 * matrix.m33 - matrix.m23 * matrix.m32,
            matrix.m13 * matrix.m32 - matrix.m12 * matrix.m33,
            matrix.m12 * matrix.m23 - matrix.m13 * matrix.m22,
            matrix.m23 * matrix.m31 - matrix.m21 * matrix.m33,
            matrix.m11 * matrix.m33 - matrix.m13 * matrix.m31,
            matrix.m13 * matrix.m21 - matrix.m11 * matrix.m23,
            matrix.m21 * matrix.m32 - matrix.m22 * matrix.m31,
            matrix.m12 * matrix.m31 - matrix.m11 * matrix.m32,
            matrix.m11 * matrix.m22 - matrix.m12 * matrix.m21);
}
///
unittest
{
    auto matrix = Matrix3(1, 2, 3, 4, 5, 6, 7, 8, 10);
    auto inverseMatrix = Matrix3(-2/3f, -4/3f, 1, -2/3f, 11/3f, -2, 1, -2, 1);

    assert(matrix.inverse == inverseMatrix);
    assert(inverseMatrix * matrix == Matrix3(1, 0, 0, 0, 1, 0, 0, 0, 1));
}

void invert(out Matrix3 matrix) pure @safe
{
    matrix = matrix.inverse;
}

Vector3 fromVector2(const scope Vector2 vector) pure nothrow @safe @nogc
{
    return Vector3(vector.x, vector.y, 1);
}

Vector2 toVector2(const scope Vector3 vector) pure nothrow @safe @nogc
{
    return Vector2(vector.x, vector.y);
}

Matrix3 fromMatrix2(const scope Matrix2 matrix) pure nothrow @safe @nogc
{
    return Matrix3(matrix.m11, matrix.m12, 0, matrix.m21, matrix.m22, 0, 0, 0, 1);
}

Vector2 truncate(const scope Vector2 vector) pure nothrow @safe @nogc
{
    import std.math : trunc;

    return Vector2(trunc(vector.x), trunc(vector.y));
}

Vector3 truncate(const scope Vector3 vector) pure nothrow @safe @nogc
{
    import std.math : trunc;

    return Vector3(trunc(vector.x), trunc(vector.y), trunc(vector.z));
}

Vector2 apply(alias fun)(const scope Vector2 vector) pure nothrow @safe @nogc
{
    return Vector2(fun(vector.x), fun(vector.y));
}

Vector3 apply(alias fun)(const scope Vector3 vector) pure nothrow @safe @nogc
{
    return Vector3(fun(vector.x), fun(vector.y), fun(vector.z));
}
