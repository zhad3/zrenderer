module sprite;

import resource : ResourceManager, ActResource, SprResource, ImfResource, ActSprite, Palette;
import linearalgebra : Vector2, Vector3;
import luad.state : LuaState;
import config : Gender, toInt;



enum SpriteType
{
    accessory,
    costume,
    garment,
    homunculus,
    mercenary,
    monster,
    npc,
    playerbody,
    playerhead,
    shadow,
    shield,
    standard,
    weapon,
}

enum PlayerAction : uint
{
    stand       = 0,
    move        = 8,
    sit         = 16,
    pickup      = 24,
    attackwait  = 32,
    attack      = 40,
    damage      = 48,
    damage2     = 56,
    dead        = 64,
    unk         = 72,
    attack2     = 80,
    attack3     = 88,
    skill       = 96,
    invalid     = 255
}

enum MonsterAction : uint
{
    stand       = 0,
    move        = 8,
    attack      = 16,
    damage      = 24,
    dead        = 32,
    invalid     = 255
}

PlayerAction intToPlayerAction(uint action) pure nothrow @safe @nogc
{
    const direction = action % 8;
    action -= direction;
    if (action > PlayerAction.skill)
    {
        return PlayerAction.invalid;
    }
    else
    {
        return cast(PlayerAction) action;
    }
}

MonsterAction intToMonsterAction(uint action) pure nothrow @safe @nogc
{
    const direction = action % 8;
    action -= direction;
    if (action > MonsterAction.dead)
    {
        return MonsterAction.invalid;
    }
    else
    {
        return cast(MonsterAction) action;
    }
}

int zIndexForSprite(const scope Sprite sprite, int direction, uint action = uint.max, uint frame = uint.max,
        ImfResource bodyImf = null) pure nothrow @safe @nogc
{
    if (sprite.type == SpriteType.shadow)
    {
        return -1;
    }

    bool topLeft = direction >= 2 && direction <= 5;

    if (topLeft)
    {
        switch (sprite.type)
        {
        case SpriteType.playerbody:
            return 15;
        case SpriteType.playerhead:
            if (bodyImf !is null && action != uint.max && frame != uint.max)
            {
                if (bodyImf.priority(1, action, frame) == 1)
                {
                    return 14; // Before body
                }
            }
            return 20;
        case SpriteType.accessory:
            return 25 - (3 - sprite.typeOrder);
        case SpriteType.weapon:
            return 30 - (2 - sprite.typeOrder);
        case SpriteType.shield:
            return 10;
        default:
            return 0;
        }
    }
    else
    {
        switch (sprite.type)
        {
        case SpriteType.playerbody:
            return 10;
        case SpriteType.playerhead:
            if (bodyImf !is null && action != uint.max && frame != uint.max)
            {
                if (bodyImf.priority(1, action, frame) == 1)
                {
                    return 9; // Before body
                }
            }
            return 15;
        case SpriteType.accessory:
            return 20 - (3 - sprite.typeOrder);
        case SpriteType.weapon:
            return 25 - (2 - sprite.typeOrder);
        case SpriteType.shield:
            return 30;
        default:
            return 0;
        }
    }
}

int zIndexForGarmentSprite(uint jobid, uint garmentid, uint action, uint frame,
        Gender gender, int direction, ref LuaState L)
{
    import luad.lfunction : LuaFunction;

    auto drawOnTopFunc = L.get!LuaFunction("_New_DrawOnTop");

    bool onTop = drawOnTopFunc.call!bool(garmentid, gender.toInt(), jobid, action, frame);

    bool topLeft = direction >= 2 && direction <= 5;

    if (onTop)
    {
        return topLeft ? 16 : 11;
    }
    else
    {
        return 5;
    }
}

class Sprite
{
private:
    ActResource _act;
    SprResource _spr;

public:
    string filename;

    // Used for depth ordering
    SpriteType type;
    int typeOrder = 0; // Describes the order of the type
    // (e.g. accessory 1, accessory 2, weapon 1, weapon 2, etc.)
    int zIndex = 0;
    bool isBaby = false;
    float scaleFactor = 0.75;

    import config : HeadDirection, toInt;
    HeadDirection headdir = HeadDirection.straight; // Used only for head sprites

    import std.typecons : Rebindable;
    private Rebindable!(const Sprite) _parent;

    this(string filename, SpriteType type = SpriteType.standard)
    {
        this.filename = filename;
        this.type = type;
    }

    this(ActResource act, SprResource spr)
    {
        this._act = act;
        this._spr = spr;
    }

    /// Throws: ResourceException
    void load(scope ResourceManager resManager)
    {
        this._spr = resManager.get!SprResource(this.filename);
        this._act = resManager.get!ActResource(this.filename);

        this._spr.load();
        this._act.load();
    }

    bool usable() const pure nothrow @safe @nogc
    {
        return this._spr.usable && this._act.usable;
    }

    const(ActResource) act() const pure nothrow @safe
    {
        return this._act;
    }

    const(SprResource) spr() const pure nothrow @safe
    {
        return this._spr;
    }

    void parent(const(Sprite) parent) pure nothrow @safe
    {
        this._parent = parent;
    }

    const(Sprite) parent() const pure nothrow @safe
    {
        return this._parent;
    }

    /**
      Unused. Attachpoints are directly referenced with the parent
      attachpoint. They do not recursively add up.
     */
    Vector3 accumulatedOffset(uint action, uint frame) const pure @safe
    {
        const attachpoints = this.act.attachpoints(action, frame);
        if (attachpoints.length == 0)
        {
            return Vector3(0, 0, 0);
        }

        const offset = Vector3(attachpoints[0].x, attachpoints[0].y, 0);

        if (this.parent !is null)
        {
            const parentOffset = this.parent.accumulatedOffset(action, frame);
            return parentOffset - offset;
        }
        else
        {
            return offset;
        }
    }

    void loadImagesOfFrame(uint action, uint frame, const Palette palette = Palette.init)
    {
        auto actframe = this.act.frame(action, frame);

        foreach (i, const sprite; actframe.sprites)
        {
            this._spr.loadImageData(sprite.sprId, sprite.sprType, palette);
        }
    }

    void loadImagesOfAction(uint action, const Palette palette = Palette.init)
    {
        auto actframes = this.act.action(action);

        for (auto i = 0; i < actframes.frames.length; ++i)
        {
            this.loadImagesOfFrame(action, i, palette);
        }
    }

    void loadAllImages()
    {
        this._spr.loadAllImageData();
    }

    void modifyActSprite(string prop, ValueType)(uint action, uint frame, uint sprite, ValueType value) pure @safe @nogc
    {
        this._act.modifySprite!(prop)(action, frame, sprite, value);
    }

    void modifyActAttachPoint(string prop, ValueType)(uint action, uint frame, uint attachpoint,
            ValueType value) pure @safe @nogc
    {
        this._act.modifyAttachpoint!(prop)(action, frame, attachpoint, value);
    }

    void addOffsetToAttachPoint(uint action, uint frame, uint attachpoint, int x, int y) pure nothrow @safe
    {
        if (frame == uint.max)
        {
            const numFrames = cast(uint) this.act.numberOfFrames(action);
            foreach (f; 0 .. numFrames)
            {
                const ap = this.act.attachpoint(action, f, attachpoint);
                this.modifyActAttachPoint!"x"(action, f, attachpoint, ap.x + x);
                this.modifyActAttachPoint!"y"(action, f, attachpoint, ap.y + y);
            }
        }
        else
        {
            const ap = this.act.attachpoint(action, frame, attachpoint);
            this.modifyActAttachPoint!"x"(action, frame, attachpoint, ap.x + x);
            this.modifyActAttachPoint!"y"(action, frame, attachpoint, ap.y + y);
        }
    }

    void applyScaling(uint action, uint frame, float scale) pure @safe
    {
        const numFrames = this.act.frames(action).length;

        void applyScalingToSprite(uint a, uint f, uint s) pure @safe
        {
            const actsprite = this.act.sprite(a, f, s);
            this.modifyActSprite!"x"(a, f, s, cast(int)(actsprite.x * scale));
            this.modifyActSprite!"y"(a, f, s, cast(int)(actsprite.y * scale));
            this.modifyActSprite!"xScale"(a, f, s, actsprite.xScale * scale);
            this.modifyActSprite!"yScale"(a, f, s, actsprite.yScale * scale);
        }

        void applyScalingToAttachPoint(uint a, uint f, uint p) pure @safe
        {
            const attachpoint = this.act.attachpoint(a, f, p);
            this.modifyActAttachPoint!"x"(a, f, p, cast(int)(attachpoint.x * scale));
            this.modifyActAttachPoint!"y"(a, f, p, cast(int)(attachpoint.y * scale));
        }

        if (frame == uint.max)
        {
            for (auto f = 0; f < numFrames; ++f)
            {
                const numSprites = this.act.sprites(action, f).length;
                for (auto s = 0; s < numSprites; ++s)
                {
                    applyScalingToSprite(action, f, s);
                }

                const numAttachPoints = this.act.attachpoints(action, f).length;
                for (auto p = 0; p < numAttachPoints; ++p)
                {
                    applyScalingToAttachPoint(action, f, p);
                }
            }
        }
        else
        {
            const numSprites = this.act.sprites(action, frame).length;
            for (auto s = 0; s < numSprites; ++s)
            {
                applyScalingToSprite(action, frame, s);
            }

            const numAttachPoints = this.act.attachpoints(action, frame).length;
            for (auto p = 0; p < numAttachPoints; ++p)
            {
                applyScalingToAttachPoint(action, frame, p);
            }
        }
    }

    import draw : DrawObject;

    DrawObject drawObjectOfSprite(const scope ActSprite actsprite,
            const scope Vector3 parentOffset = Vector3.init) const pure
    {
        const sprimage = this.spr.image(actsprite.sprId, actsprite.sprType);

        import draw : RawImage;

        if (sprimage == RawImage.init)
        {
            return DrawObject.init;
        }

        TransformMatrix transform = this.transformOfSprite(actsprite, sprimage.width,
                sprimage.height, parentOffset);
        Box boundingBox = this.boundingBoxOfTransform(transform);

        DrawObject drawobj = {
            tint: actsprite.tint,
            boundingBox: boundingBox,
            transform: transform
        };

        return drawobj;
    }

    DrawObject drawObjectsOfFrame(uint action, uint frame) const pure
    {
        DrawObject drawObject;
        drawObject.boundingBox.toInfinity();
        drawObject.children = new DrawObject[this.act.sprites(action, frame).length];

        Vector3 parentOffset = Vector3(0, 0, 0);

        if (this.parent !is null)
        {
            uint parentframeindex = frame;
            const playerAction = intToPlayerAction(action);
            if (this.type == SpriteType.accessory &&
                    (playerAction == PlayerAction.stand || playerAction == PlayerAction.sit))
            {
                if (this.headdir != HeadDirection.all)
                {
                    parentframeindex = this.headdir.toInt();
                }
                else if (this.act.frames(action).length >= 3)
                {
                    parentframeindex = frame / (this.act.frames(action).length / 3);
                }
            }
            if (this.parent.act.attachpoints(action, parentframeindex).length > 0)
            {
                const parentAttachpoint = this.parent.act.attachpoint(action, parentframeindex, 0);
                parentOffset = Vector3(parentAttachpoint.x, parentAttachpoint.y, 0);
            }
            //parentOffset = this.parent.accumulatedOffset(action, frame);

            if (this.act.attachpoints(action, frame).length > 0)
            {
                const attachpoint = this.act.attachpoint(action, frame, 0);
                parentOffset = parentOffset - Vector3(attachpoint.x, attachpoint.y, 0);
            }
        }

        foreach (i, const actsprite; this.act.sprites(action, frame))
        {
            auto spriteObj = this.drawObjectOfSprite(actsprite, parentOffset);
            if (spriteObj == DrawObject.init)
            {
                continue;
            }
            drawObject.children[i] = spriteObj;
            drawObject.boundingBox.updateBounds(drawObject.children[i].boundingBox);
        }

        if (drawObject.boundingBox.isInfinite)
        {
            return DrawObject.init;
        }

        return drawObject;
    }

    DrawObject drawObjectsOfAction(uint action) const pure
    {
        DrawObject drawObject;
        drawObject.boundingBox.toInfinity();

        ulong frameFrom = 0;
        ulong frameTo = this.act.frames(action).length;

        if ((this.type == SpriteType.playerhead || this.type == SpriteType.accessory)
                && this.headdir != HeadDirection.all && frameTo >= 3)
        {
            const playerAction = intToPlayerAction(action);
            if (playerAction == PlayerAction.stand || playerAction == PlayerAction.sit)
            {
                const frameCount = frameTo / 3;
                frameFrom = this.headdir.toInt() * frameCount;
                frameTo = frameFrom + frameCount;
            }
        }

        drawObject.children = new DrawObject[frameTo - frameFrom];

        for (auto i = frameFrom; i < frameTo; ++i)
        {
            drawObject.children[i - frameFrom] = this.drawObjectsOfFrame(action, cast(uint) i);
            drawObject.boundingBox.updateBounds(drawObject.children[i - frameFrom].boundingBox);
        }

        if (drawObject.boundingBox.isInfinite)
        {
            return DrawObject.init;
        }

        return drawObject;
    }

    import linearalgebra : Box, TransformMatrix, PI_180;

    Box boundingBoxOfSprite(uint action, uint frame, uint sprite) const pure @safe
    {
        const actsprite = this.act.sprite(action, frame, sprite);
        const sprImage = this.spr.image(actsprite.sprId, actsprite.sprType);
        return this.boundingBoxOfSprite(actsprite, sprImage.width, sprImage.height);
    }

    Box boundingBoxOfSprite(const scope ActSprite actsprite) const pure @safe
    {
        const sprImage = this.spr.image(actsprite.sprId, actsprite.sprType);
        return this.boundingBoxOfSprite(actsprite, sprImage.width, sprImage.height);
    }

    Box boundingBoxOfSprite(const scope ActSprite actsprite, uint width, uint height) const pure nothrow @safe @nogc
    {
        auto transform = transformOfSprite(actsprite, width, height);
        return boundingBoxOfTransform(transform);
    }

    Box boundingBoxOfTransform(const scope TransformMatrix transform) const pure nothrow @safe @nogc
    {
        Box boundingBox;
        boundingBox.toInfinity();

        Vector3 topLeft = transform * Vector3(0, 0, 1);
        Vector3 topRight = transform * Vector3(transform.size.x, 0, 1);
        Vector3 bottomLeft = transform * Vector3(0, transform.size.y, 1);
        Vector3 bottomRight = transform * Vector3(transform.size.x, transform.size.y, 1);

        import linearalgebra : toVector2;

        boundingBox.updateBounds(topLeft.toVector2(), topRight.toVector2());
        boundingBox.updateBounds(bottomLeft.toVector2(), bottomRight.toVector2());

        return boundingBox;
    }

    private TransformMatrix transformOfSprite(uint action, uint frame, uint sprite) const pure @safe
    {
        const actsprite = this.act.sprite(action, frame, sprite);
        const sprImage = this.spr.image(actsprite.sprId, actsprite.sprType);
        auto width = sprImage.width;
        auto height = sprImage.height;

        return this.transformOfSprite(actsprite, width, height);
    }

    private TransformMatrix transformOfSprite(const scope ActSprite actsprite,
            uint width, uint height, const scope Vector3 parentOffset = Vector3.init) const pure nothrow @safe @nogc
    {
        const mirrored = (actsprite.flags & 1);

        TransformMatrix transform;
        transform.setOrigin(0.5, 0.5);
        transform.setSize(width - (mirrored * 0.5), height); // Dirty hack to fix rounding errors on mirrored sprites
        transform.scale(actsprite.xScale * (mirrored > 0 ? -1f : 1f), actsprite.yScale);
        transform.translate(actsprite.x + parentOffset.x, actsprite.y + parentOffset.y);
        transform.rotate(actsprite.rotation * PI_180);

        transform.calculate();

        return transform;
    }
}
