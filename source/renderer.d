module renderer;

import sprite;
import draw : Color, RawImage, DrawObject, Canvas;
import linearalgebra : TransformMatrix, Box, Vector3, Matrix3, inverse, PI_180;
import imageformats.png;

import std.stdio : writefln;

void drawSpriteOnImage(ref RawImage destImage, const scope DrawObject spriteObj,
        const scope RawImage sourceImage, const scope Vector3 offset) pure @safe @nogc
{
    if (spriteObj.tint.a == 0x00)
    {
        return;
    }

    const transformedWidth = spriteObj.boundingBox.width;
    const transformedHeight = spriteObj.boundingBox.height;
    const inverseTransform = spriteObj.transform.inverse;

    const pixelCount = transformedWidth * transformedHeight;

    for (auto i = 0; i < pixelCount; ++i)
    {
        uint transformedX = (i % transformedWidth);
        uint transformedY = (i / transformedWidth);

        import std.math : round, floor, ceil;

        int destX = transformedX + cast(int) offset.x;
        int destY = transformedY + cast(int) offset.y;

        if (destX < 0 || destX >= destImage.width ||
                destY < 0 || destY >= destImage.height)
        {
            continue;
        }

        const outputIndex = cast(ulong)(destX + destY * destImage.width);

        auto outputPixel = &destImage.pixels[outputIndex];

        debug {
            if (transformedX == 0 || transformedX == transformedWidth - 1 ||
                    transformedY == 0 || transformedY == transformedHeight - 1)
            {
                *outputPixel = alphaBlend(*outputPixel, Color(0x55FF00FF));
            }
        }

        const sourceOffset = Vector3(
                cast(float) transformedX + spriteObj.boundingBox.x1,
                cast(float) transformedY + spriteObj.boundingBox.y1,
                1);

        import linearalgebra : truncate, apply;

        auto sourcePoint = apply!round(inverseTransform * sourceOffset);

        if (sourcePoint.x < 0 || sourcePoint.x >= sourceImage.width ||
                sourcePoint.y < 0 || sourcePoint.y >= sourceImage.height)
        {
            continue;
        }

        const sourceIndex = cast(ulong)(sourcePoint.x + sourcePoint.y * sourceImage.width);
        Color sourcePixel = sourceImage.pixels[sourceIndex];

        if (sourcePixel.a == 0x00)
        {
            continue;
        }

        const tintedPixel = tintPixel(sourcePixel, spriteObj.tint);

        *outputPixel = alphaBlend(*outputPixel, tintedPixel);
    }
}

void drawFrameOnImage(ref RawImage destImage, const scope Sprite sprite, uint action, uint frame,
        const scope DrawObject frameobj, const scope Vector3 offset)
{
    foreach (s, spriteobj; frameobj.children)
    {
        if (spriteobj == DrawObject.init)
        {
            continue;
        }
        const spriteOffset = Vector3(spriteobj.boundingBox.x1, spriteobj.boundingBox.y1, 0);
        const actsprite = sprite.act.sprite(action, frame, cast(uint) s);
        const sprimage = sprite.spr.image(actsprite.sprId, actsprite.sprType);
        drawSpriteOnImage(destImage, spriteobj, sprimage, spriteOffset - offset);
    }
}

RawImage[] drawAction(scope Sprite sprite, uint action)
{

    DrawObject drawobjects = sprite.drawObjectsOfAction(action);

    RawImage[] outputImage = new RawImage[drawobjects.children.length];

    const totalWidth = drawobjects.boundingBox.width;
    const totalHeight = drawobjects.boundingBox.height;

    const offset = Vector3(drawobjects.boundingBox.x1, drawobjects.boundingBox.y1, 0);

    foreach (i, frameobj; drawobjects.children)
    {
        outputImage[i].width = totalWidth;
        outputImage[i].height = totalHeight;
        outputImage[i].pixels = new Color[totalWidth * totalHeight];

        drawFrameOnImage(outputImage[i], sprite, action, cast(uint) i, frameobj, offset);

        debug
        {
            import std.math : floor;

            for (auto x = 0; x < totalWidth; ++x)
            {
                const index = x + cast(uint) floor(-offset.y * totalWidth);
                outputImage[i].pixels[index] = alphaBlend(outputImage[i].pixels[index], Color(
                        0x550000FF));
            }
            for (auto y = 0; y < totalHeight; ++y)
            {
                const index = cast(uint)(-offset.x) + (y * totalWidth);
                outputImage[i].pixels[index] = alphaBlend(outputImage[i].pixels[index], Color(
                        0x550000FF));
            }
        }
    }

    return outputImage;
}

alias sortDelegate = void delegate(ref int[] index, uint frame);

RawImage[] drawPlayer(scope Sprite[] sprites, uint action, uint frame,
        sortDelegate sortDg, immutable(Canvas) canvas)
{
    DrawObject[] drawobjects;
    drawobjects.reserve(sprites.length);

    Box totalBoundingBox;
    totalBoundingBox.toInfinity();

    bool drawSingleFrame = frame < uint.max;
    ulong startframe = drawSingleFrame ? frame : 0;
    ulong maxframes = drawSingleFrame ? frame + 1 : 0;

    foreach (sprite; sprites)
    {
        uint actionindex = (sprite.type == SpriteType.shadow) ? 0 : action;
        uint frameindex = (sprite.type == SpriteType.shadow) ? 0 : frame;

        DrawObject drawobject;
        if (!drawSingleFrame)
        {
            drawobject = sprite.drawObjectsOfAction(actionindex);

            import std.algorithm : max;

            maxframes = max(maxframes, drawobject.children.length);
        }
        else
        {
            const playerAction = intToPlayerAction(actionindex);
            if (sprite.type == SpriteType.accessory && sprite.act.frames(actionindex).length > 3 &&
                    (playerAction == PlayerAction.stand || playerAction == PlayerAction.sit))
            {
                drawobject = sprite.drawObjectsOfFrame(actionindex,
                        cast(uint) ((frameindex % 3) * sprite.act.frames(actionindex).length / 3));
            }
            else
            {
                drawobject = sprite.drawObjectsOfFrame(actionindex, frameindex);
            }
        }

        totalBoundingBox.updateBounds(drawobject.boundingBox);

        drawobjects ~= drawobject;
    }

    const totalWidth = canvas != Canvas.init ? canvas.width : totalBoundingBox.width;
    const totalHeight = canvas != Canvas.init ? canvas.height : totalBoundingBox.height;

    if (totalWidth == 0 || totalHeight == 0)
    {
        return [];
    }

    RawImage[] outputImage = new RawImage[maxframes - startframe];

    const offset = Vector3(
            canvas != Canvas.init ? -canvas.originx : totalBoundingBox.x1,
            canvas != Canvas.init ? -canvas.originy : totalBoundingBox.y1,
            0);

    import std.algorithm.sorting : makeIndex;

    int[] sortIndex = new int[sprites.length];
    makeIndex!"a.zIndex < b.zIndex"(sprites, sortIndex);

    for (auto i = startframe; i < maxframes; ++i)
    {
        outputImage[i - startframe].width = totalWidth;
        outputImage[i - startframe].height = totalHeight;
        outputImage[i - startframe].pixels = new Color[totalWidth * totalHeight];

        if (i > startframe)
        {
            sortDg(sortIndex, cast(uint) i);
        }

        for (auto d = 0; d < sortIndex.length; ++d)
        {
            import std.conv : to;

            auto drawobject = drawobjects[sortIndex[d]];

            if (!drawSingleFrame && drawobject.children.length == 0)
            {
                continue;
            }

            ulong frameindex = i; // Overwrite frame for shadow and animated headgears
            uint actionindex = action; // Overwrite action for shadow
            ulong frameoffset = 0; // Offset for animated headgears

            const sprite = sprites[sortIndex[d]];

            const playerAction = intToPlayerAction(action);

            if (sprite.type == SpriteType.shadow)
            {
                actionindex = 0;
                frameindex = 0;
            }
            else if ((sprite.type == SpriteType.playerhead || sprite.type == SpriteType.accessory) &&
                    (playerAction == PlayerAction.stand || playerAction == PlayerAction.sit))
            {
                import config : HeadDirection, toInt;

                if (!drawSingleFrame && maxframes >= 3)
                {
                    const frameCountOfCurrentSprite = sprite.act.frames(action).length;
                    if (sprite.headdir != HeadDirection.all)
                    {
                        frameoffset = sprite.headdir.toInt() * frameCountOfCurrentSprite / 3;
                    }
                    else if (sprite.type == SpriteType.playerhead)
                    {
                        frameindex = i / (maxframes / 3);
                    }
                    else if (frameCountOfCurrentSprite >= 3)
                    {
                        // Other animated headgears
                        const bigStep = maxframes / 3;
                        const smallStep = frameCountOfCurrentSprite / 3;
                        const index = i / bigStep;
                        const alignment = smallStep - ((index * bigStep) % smallStep);
                        frameindex = (i + alignment) % smallStep + index * smallStep;
                    }
                }
                else if (sprite.act.frames(action).length >= 3)
                {
                    frameoffset = i * sprite.act.frames(action).length / 3 - frameindex;
                }
            }

            if (!drawSingleFrame && frameindex >= drawobject.children.length)
            {
                if (drawobject.children.length == 3 && maxframes >= 3)
                {
                    frameindex = i / (maxframes / 3) % drawobject.children.length;
                }
                else
                {
                    frameindex = frameindex % drawobject.children.length;
                }
            }

            DrawObject frameobj;
            if (!drawSingleFrame)
            {
                frameobj = drawobject.children[frameindex];
            }
            else
            {
                frameobj = drawobject;
            }

            drawFrameOnImage(outputImage[i - startframe], sprites[sortIndex[d]], actionindex,
                    cast(uint) (frameindex + frameoffset), frameobj, offset);

            debug
            {
                import std.math : floor;

                for (auto x = 0; x < totalWidth; ++x)
                {
                    const index = x + cast(uint) floor(-offset.y * totalWidth);
                    if (index > 0 && index < outputImage[i - startframe].pixels.length)
                    {
                        outputImage[i - startframe].pixels[index] = alphaBlend(
                                outputImage[i - startframe].pixels[index],
                                Color(0x550000FF));
                    }
                }
                for (auto y = 0; y < totalHeight; ++y)
                {
                    const index = cast(uint)(-offset.x) + (y * totalWidth);
                    if (index > 0 && index < outputImage[i - startframe].pixels.length)
                    {
                        outputImage[i - startframe].pixels[index] = alphaBlend(
                                outputImage[i - startframe].pixels[index],
                                Color(0x550000FF));
                    }
                }
            }
        }
    }

    return outputImage;
}

Color alphaBlend(const scope Color dest, const scope Color src) pure nothrow @safe @nogc
{
    Color blended;

    if (dest.a == 0x00 || src.a == 0xFF)
    {
        blended = src;
    }
    else
    {
        auto new_alpha = src.a + (dest.a * (0xFF - src.a) / 0xFF);
        blended.r = (src.r * src.a / 0xFF + (dest.r * dest.a * (0xFF - src.a) / (0xFF * 0xFF))) * 0xFF / new_alpha;
        blended.g = (src.g * src.a / 0xFF + (dest.g * dest.a * (0xFF - src.a) / (0xFF * 0xFF))) * 0xFF / new_alpha;
        blended.b = (src.b * src.a / 0xFF + (dest.b * dest.a * (0xFF - src.a) / (0xFF * 0xFF))) * 0xFF / new_alpha;
        blended.a = cast(ubyte) new_alpha;
    }

    return blended;
}

Color tintPixel(const scope Color pixel, const scope Color tint) pure nothrow @safe @nogc
{
    Color tinted;
    tinted.r = tint.r * pixel.r / 0xFF;
    tinted.g = tint.g * pixel.g / 0xFF;
    tinted.b = tint.b * pixel.b / 0xFF;
    tinted.a = tint.a * pixel.a / 0xFF;

    return tinted;
}

RawImage[] applyBabyScaling(return ref RawImage[] images, float scaleFactor)
{
    import std.math : isClose;

    if (images.length == 0 || isClose(scaleFactor, 1f))
    {
        return images;
    }

    const newWidth = cast(uint) (images[0].width * scaleFactor);
    const newHeight = cast(uint) (images[0].height * scaleFactor);

    const newPixelCount = newWidth * newHeight;

    Color[][] newPixels = new Color[][images.length];

    const inverseScale = isClose(scaleFactor, 0f) ? 0f : 1f / scaleFactor;

    foreach (i, ref image; images)
    {
        newPixels[i] = new Color[newPixelCount];
        foreach (p, ref pixel; newPixels[i])
        {
            const dstX = p % newWidth;
            const dstY = p / newWidth;

            const uint srcX = cast(uint) (dstX * inverseScale);
            const uint srcY = cast(uint) (dstY * inverseScale);

            if (srcX >= image.width || srcX < 0 || srcY >= image.height || srcY < 0)
            {
                continue;
            }

            pixel = image.pixels[cast(ulong) (srcX + srcY * image.width)];
        }

        image.width = newWidth;
        image.height = newHeight;
        image.pixels = newPixels[i];
    }

    return images;
}
