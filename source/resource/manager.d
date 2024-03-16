module resource.manager;

import resource.base : BaseResource, ResourceException;
import sprite;

class ResourceManager
{
    private string _resourcePath;

    this(string resourcePath) pure nothrow @safe
    {
        this._resourcePath = resourcePath;
    }

    ResourceType get(ResourceType)(string filename)
        if (is(ResourceType : BaseResource))
    {
        return new ResourceType(filename, this._resourcePath);
    }

    Sprite getSprite(string filename, SpriteType type = SpriteType.standard)
    {
        return getSprite(filename, filename, type);
    }

    Sprite getSprite(string actfilename, string sprfilename, SpriteType type = SpriteType.standard)
    {
        import resource.act : ActResource;
        import resource.spr : SprResource;

        auto act = this.get!ActResource(actfilename);
        auto spr = this.get!SprResource(sprfilename);

        act.load();
        spr.load();

        auto sprite = new Sprite(act, spr);
        sprite.filename = actfilename;
        sprite.type = type;

        import std.exception : enforce;
        import std.format : format;

        enforce!ResourceException(sprite.usable, format("Sprite's act or spr resource is not usable. " ~
                "Making this sprite (ACT: %s, SPR: %s) also unusable.", actfilename, sprfilename));

        return sprite;
    }

    Sprite getSprite(ActResource act, SprResource spr, SpriteType type = SpriteType.standard)
    {
        auto sprite = new Sprite(act, spr);
        sprite.filename = act.filename();
        sprite.type = type;

        return sprite;
    }

    bool exists(ResourceType)(string filename)
        if (is(ResourceType : BaseResource))
    {
        import std.file : exists;
        import resource.base : buildFilepath;

        bool resourceExists = false;

        static if (ResourceType.fileExtensions.length > 1)
        {
            foreach (ext; ResourceType.fileExtensions)
            {
                scope path = buildFilepath(this._resourcePath, ResourceType.filePath, filename, ext);
                resourceExists = exists(path);
                if (resourceExists)
                {
                    break;
                }
            }
        }
        else static if (ResourceType.fileExtensions.length == 0)
        {
            resourceExists = exists(buildFilepath(this._resourcePath, ResourceType.filePath, filename));
        }
        else
        {
            scope path = buildFilepath(this._resourcePath, ResourceType.filePath, filename,
                    ResourceType.fileExtensions[0]);
            resourceExists = exists(path);
        }

        return resourceExists;
    }
}
