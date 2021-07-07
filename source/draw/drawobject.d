module draw.drawobject;

import draw.color;
import draw.rawimage;
import linearalgebra : Vector3, Box, TransformMatrix;
import sprite : Sprite;

struct DrawObject
{
    Color tint;
    Vector3 offset;
    Box boundingBox;
    TransformMatrix transform;
    DrawObject[] children;
}

