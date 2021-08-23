module app;
import config : Config, Gender, HeadDirection;
import luad.state : LuaState;
import resource : ResourceManager;
import resolver;
import sprite;

alias LogFunc = void delegate(string msg);

void createOutputDirectory(string outputDirectory) @safe
{
    import std.file : mkdirRecurse, exists;

    if (!outputDirectory.exists)
    {
        mkdirRecurse(outputDirectory);
    }
}

bool isJobArgValid(const(string)[] jobids) pure @safe
{
    bool isValid = true;

    foreach (jobidstr; jobids)
    {
        import std.algorithm.searching : countUntil;
        import std.string : representation;

        auto rangeIndex = countUntil(jobidstr.representation, '-');

        import std.conv : to, ConvException;

        if (rangeIndex == 0)
        {
            isValid = false;
            break;
        }
        else if (rangeIndex < 0)
        {
            try
            {
                jobidstr.to!uint;
            }
            catch (ConvException err)
            {
                isValid = false;
                break;
            }
        }
        else
        {
            if (rangeIndex + 1 >= jobidstr.length)
            {
                isValid = false;
                break;
            }

            try
            {
                auto start = jobidstr[0 .. rangeIndex].to!uint;
                auto end = jobidstr[rangeIndex + 1 .. $].to!uint;

                if (end < start)
                {
                    isValid = false;
                    break;
                }
            }
            catch (ConvException err)
            {
                isValid = false;
                break;
            }
        }
    }

    return isValid;
}

string[] run(immutable Config config, LogFunc log, LuaState L = null,
        ResourceManager resManager = null, Resolver resolve = null)
{
    // Nothing to draw
    if (config.job.length == 0)
    {
        return [];
    }

    if (L is null)
    {
        import luad.error : LuaErrorException;

        try
        {
            L = new LuaState;
            L.openLibs();
        }
        catch (LuaErrorException err)
        {
            log(err.msg);
            return [];
        }
    }

    if (resManager is null)
    {
        resManager = new ResourceManager(config.resourcepath);

        import luamanager : loadRequiredLuaFiles;
        import resource : ResourceException;

        try
        {
            loadRequiredLuaFiles(L, resManager);
        }
        catch (ResourceException err)
        {
            log(err.msg);
            return [];
        }
    }

    if (resolve is null)
    {
        resolve = new Resolver(L);
    }

    return process(config, log, L, resManager, resolve);
}

string[] process(immutable Config config, LogFunc log, LuaState L,
        ResourceManager resManager, Resolver resolve)
{
    string[] filenames;

    // A bad guess
    filenames.reserve(config.job.length);

    foreach (jobidstr; config.job)
    {
        uint startJob;
        uint endJob;
        float animationInterval = 12;
        int requestFrame = config.frame;

        import std.algorithm.searching : countUntil;
        import std.string : representation;

        auto rangeIndex = countUntil(jobidstr.representation, '-');

        import std.conv : to, ConvException;

        // We don't catch exceptions here because isJobArgValid should have taken care of errors
        if (rangeIndex < 0)
        {
            startJob = jobidstr.to!uint;
            endJob = startJob;
        }
        else
        {
            startJob = jobidstr[0 .. rangeIndex].to!uint;
            endJob = jobidstr[rangeIndex + 1 .. $].to!uint;
        }

        for (auto jobid = startJob; jobid <= endJob; ++jobid)
        {

            Sprite[] sprites;

            if (isPlayer(jobid))
            {
                sprites = processPlayer(jobid, log, config, resolve, resManager, L, animationInterval, requestFrame);
            }
            else
            {
                sprites = processNonPlayer(jobid, log, config, resolve, resManager, L, animationInterval);
            }

            if (shouldDrawShadow(config.enableShadow, jobid, config.action))
            {
                auto shadowsprite = resManager.getSprite("shadow", SpriteType.shadow);
                shadowsprite.zIndex = -1;
                shadowsprite.loadImagesOfFrame(0, 0);

                import luamanager : shadowfactor;

                float scale = shadowfactor(jobid, L);
                if (scale >= -float.epsilon && scale <= float.epsilon)
                {
                    shadowsprite.modifyActSprite!"xScale"(0, 0, 0, scale);
                    shadowsprite.modifyActSprite!"yScale"(0, 0, 0, scale);
                }

                sprites ~= shadowsprite;
            }

            import std.algorithm : sort;

            sprites.sort!"a.zIndex < b.zIndex";

            import draw : RawImage;
            import renderer : drawPlayer;

            void sortIndexDelegate(ref int[] index, uint frame)
            {
                int direction = config.action % 8;

                import std.algorithm.iteration : filter, each;

                sprites.filter!(a => a.type == SpriteType.garment)
                    .each!(s => s.zIndex = zIndexForGarmentSprite(jobid, config.garment, config.action,
                            frame, config.gender, direction, L));

                import std.algorithm.sorting : makeIndex;

                makeIndex!"a.zIndex < b.zIndex"(sprites, index);
            }

            RawImage[] images = drawPlayer(sprites, config.action,
                    (requestFrame < 0) ? uint.max : requestFrame, &sortIndexDelegate);

            if (isBaby(jobid))
            {
                import renderer : applyBabyScaling;

                images.applyBabyScaling(0.75);
            }

            if (images.length > 0)
            {
                import imageformats.png : saveToPngFile;
                import std.format : format;
                import std.path : buildPath;

                if (config.singleframes)
                {
                    foreach (i, image; images)
                    {
                        auto filename = buildPath(config.outdir, format("%d_%d_%d.png", jobid, config.action, i));

                        saveToPngFile(image, filename);

                        filenames ~= filename;
                    }
                }

                if (images.length > 1)
                {
                    import imageformats.png : saveToApngFile;

                    auto filename = buildPath(config.outdir, format("%d_%d.png", jobid, config.action));

                    saveToApngFile(images, filename, (25 * animationInterval).to!ushort);

                    filenames ~= filename;
                }
                else
                {
                    if (requestFrame < 0)
                    {
                        auto filename = buildPath(config.outdir, format("%d_%d.png", jobid, config.action));

                        saveToPngFile(images[0], filename);

                        filenames ~= filename;
                    }
                    else
                    {
                        auto filename = buildPath(config.outdir,
                                format("%d_%d_%d.png", jobid, config.action, requestFrame));
                        saveToPngFile(images[0], filename);

                        filenames ~= filename;
                    }
                }
            }
        }
    }

    return filenames;
}

Sprite[] processNonPlayer(uint jobid, LogFunc log, immutable Config config, Resolver resolve,
        ResourceManager resManager, ref LuaState L, out float interval)
{
    const jobspritepath = resolve.nonPlayerSprite(jobid);
    if (jobspritepath.length == 0)
    {
        return [];
    }

    import resource.base : ResourceException;

    Sprite jobsprite;

    try
    {
        jobsprite = resManager.getSprite(jobspritepath);
    }
    catch (ResourceException err)
    {
        log(err.msg);
        return [];
    }

    if (config.frame < 0)
    {
        jobsprite.loadImagesOfAction(config.action);
    }
    else
    {
        jobsprite.loadImagesOfFrame(config.action, config.frame);
    }

    auto sprites = [jobsprite];

    interval = jobsprite.act.action(config.action).interval;

    if (isMercenary(jobid))
    {
        // Attach head to mercenary. Gender is derived from the job id
        const gender = (jobid - 6017) <= 9 ? Gender.female : Gender.male;
        auto headspritepath = resolve.playerHeadSprite(jobid, config.head, gender);
        if (headspritepath.length > 0)
        {
            auto headsprite = resManager.getSprite(headspritepath);
            headsprite.parent(jobsprite);

            if (config.frame < 0)
            {
                headsprite.loadImagesOfAction(config.action);
            }
            else
            {
                headsprite.loadImagesOfFrame(config.action, config.frame);
            }
            sprites ~= headsprite;
        }
    }

    return sprites;
}

Sprite[] processPlayer(uint jobid, LogFunc log, immutable Config config, Resolver resolve,
        ResourceManager resManager, ref LuaState L, out float interval, ref int requestFrame)
{
    import std.exception : ErrnoException;
    import resource.base : ResourceException;

    import std.stdio : writeln;

    uint direction = config.action % 8;

    const playerAction = intToPlayerAction(config.action);
    bool overwriteFrame = config.headdir != HeadDirection.all && config.frame < 0 &&
        (playerAction == PlayerAction.stand || playerAction == PlayerAction.sit);

    const bodyspritepath = resolve.playerBodySprite(jobid, config.gender);
    if (bodyspritepath.length == 0)
    {
        import std.format : format;

        log(format("Couldn't resolve player body sprite for job %d and gender %s", jobid, config.gender));
        return [];
    }

    Sprite bodysprite;

    try
    {
        bodysprite = resManager.getSprite(bodyspritepath, SpriteType.playerbody);
        bodysprite.zIndex = zIndexForSprite(bodysprite, direction);
    }
    catch (ResourceException err)
    {
        log(err.msg);
        return [];
    }

    interval = bodysprite.act.action(config.action).interval;

    Sprite[] sprites;
    sprites.reserve(10);

    sprites ~= bodysprite;

    const headspritepath = resolve.playerHeadSprite(jobid, config.head, config.gender);
    Sprite headsprite;

    try
    {
        headsprite = resManager.getSprite(headspritepath, SpriteType.playerhead);
        headsprite.zIndex = zIndexForSprite(headsprite, direction);
        headsprite.parent(bodysprite);
        headsprite.headdir = config.headdir;
        sprites ~= headsprite;
    }
    catch (ResourceException err)
    {
        log(err.msg);
    }

    if (config.weapon > 0)
    {
        const weaponspritepath = resolve.weaponSprite(jobid, config.weapon, config.gender);
        if (weaponspritepath.length > 0)
        {
            try
            {
                auto weaponsprite = resManager.getSprite(weaponspritepath, SpriteType.weapon);
                weaponsprite.typeOrder = 1;
                weaponsprite.zIndex = zIndexForSprite(weaponsprite, direction);
                sprites ~= weaponsprite;

                // Weapon Slash
                auto weaponslashsprite = resManager.getSprite(weaponspritepath ~ "_검광", SpriteType.weapon);
                weaponslashsprite.typeOrder = 0;
                weaponslashsprite.zIndex = zIndexForSprite(weaponslashsprite, direction);
                sprites ~= weaponslashsprite;
            }
            catch (ResourceException err)
            {
                log(err.msg);
            }
        }
    }

    if (config.shield > 0)
    {
        const shieldspritepath = resolve.shieldSprite(jobid, config.shield, config.gender);
        if (shieldspritepath.length > 0)
        {
            try
            {
                auto shieldsprite = resManager.getSprite(shieldspritepath, SpriteType.shield);
                shieldsprite.zIndex = zIndexForSprite(shieldsprite, direction);
                sprites ~= shieldsprite;
            }
            catch (ResourceException err)
            {
                log(err.msg);
            }
        }
    }

    if (config.headgear.length > 0)
    {
        import std.algorithm : min;

        const numHeadgears = min(3, config.headgear.length);

        for (auto h = 0; h < numHeadgears; ++h)
        {
            if (config.headgear[h] > 0)
            {
                const headgearspritepath = resolve.headgearSprite(config.headgear[h], config.gender);
                try
                {
                    auto headgearsprite = resManager.getSprite(headgearspritepath, SpriteType.accessory);
                    headgearsprite.typeOrder = h;
                    headgearsprite.zIndex = zIndexForSprite(headgearsprite, direction);
                    headgearsprite.parent(bodysprite);
                    headgearsprite.headdir = config.headdir;
                    sprites ~= headgearsprite;

                    // Set to all frames if headgear has more frames
                    if (headgearsprite.act.frames(config.action).length > 3)
                    {
                        overwriteFrame = false;
                    }
                }
                catch (ResourceException err)
                {
                    log(err.msg);
                }
            }
        }
    }

    if (config.garment > 0)
    {
        auto garmentspritepath = resolve.garmentSprite(jobid, config.garment, config.gender);
        if (garmentspritepath.length > 0)
        {
            import resource : ActResource;

            if (!resManager.exists!ActResource(garmentspritepath))
            {
                // The korean name doesn't seem to exist. Let's just try with the english name
                // If it also doesn't exist the following try block will catch the exception.
                garmentspritepath = resolve.garmentSprite(jobid, config.garment, config.gender, true);
            }
            try
            {
                auto garmentsprite = resManager.getSprite(garmentspritepath, SpriteType.garment);
                garmentsprite.zIndex = zIndexForGarmentSprite(jobid, config.garment,
                        config.action, config.frame < 0 ? 0 : config.frame, config.gender, direction, L);
                garmentsprite.parent(bodysprite);
                sprites ~= garmentsprite;
            }
            catch (ResourceException err)
            {
                log(err.msg);
            }
        }
    }

    import resource : Palette, PaletteResource;

    PaletteResource bodypalette;
    PaletteResource headpalette;

    if (config.bodyPalette > -1)
    {
        auto bodypalettepath = resolve.bodyPalette(jobid, config.bodyPalette, config.gender);
        if (bodypalettepath.length > 0)
        {
            try
            {
                bodypalette = resManager.get!PaletteResource(bodypalettepath);
                bodypalette.load();
            }
            catch (ResourceException err)
            {
                log(err.msg);
            }
        }
    }

    if (config.headPalette > -1)
    {
        auto headpalettepath = resolve.headPalette(jobid, config.head, config.headPalette, config.gender);
        if (headpalettepath.length > 0)
        {
            try
            {
                headpalette = resManager.get!PaletteResource(headpalettepath);
                headpalette.load();
            }
            catch (ResourceException err)
            {
                log(err.msg);
            }
        }
    }

    if (overwriteFrame)
    {
        import config : toInt;

        requestFrame = config.headdir.toInt();
    }

    if (requestFrame < 0)
    {
        foreach (sprite; sprites)
        {
            if (sprite.type == SpriteType.playerbody)
            {
                bodysprite.loadImagesOfAction(config.action,
                        bodypalette !is null && bodypalette.usable ? bodypalette.palette : Palette.init);
            }
            else if (sprite.type == SpriteType.playerhead)
            {
                headsprite.loadImagesOfAction(config.action,
                        headpalette !is null && headpalette.usable ? headpalette.palette : Palette.init);
            }
            else
            {
                sprite.loadImagesOfAction(config.action);
            }
        }
    }
    else
    {
        foreach (sprite; sprites)
        {
            if (sprite.type == SpriteType.playerbody)
            {
                bodysprite.loadImagesOfFrame(config.action, requestFrame,
                        bodypalette !is null && bodypalette.usable ? bodypalette.palette : Palette.init);
            }
            else if (sprite.type == SpriteType.playerhead)
            {
                headsprite.loadImagesOfFrame(config.action, requestFrame,
                        headpalette !is null && headpalette.usable ? headpalette.palette : Palette.init);
            }
            else if (sprite.type == SpriteType.accessory && sprite.act.frames(config.action).length > 3)
            {
                sprite.loadImagesOfFrame(config.action,
                        cast(uint)((requestFrame % 3) * sprite.act.frames(config.action).length / 3));
            }
            else
            {
                sprite.loadImagesOfFrame(config.action, requestFrame);
            }
        }
    }

    return sprites;
}

bool shouldDrawShadow(bool enableShadow, uint jobid, uint action) pure nothrow @safe @nogc
{
    if (!enableShadow)
    {
        return false;
    }

    if (isPlayer(jobid))
    {
        const playerAction = intToPlayerAction(action);

        if (playerAction == PlayerAction.sit || playerAction == PlayerAction.dead)
        {
            return false;
        }
    }
    else if (!isNPC(jobid))
    {
        const monsterAction = intToMonsterAction(action);

        if (monsterAction == MonsterAction.dead)
        {
            return false;
        }
    }

    return true;
}
