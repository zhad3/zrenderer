module app;

import config : Config, Gender, HeadDirection, OutputFormat;
import draw : Canvas, canvasFromString;
import logging : LogLevel, LogDg;
import luad.state : LuaState;
import resolver;
import resource : ResourceManager, ResourceException, ImfResource;
import sprite;
import std.zip : ZipArchive;
import validation;

void createOutputDirectory(string outputDirectory) @safe
{
    import std.file : mkdirRecurse, exists;

    if (!outputDirectory.exists)
    {
        mkdirRecurse(outputDirectory);
    }
}

string[] run(immutable Config config, LogDg log, LuaState L = null,
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
            log(LogLevel.critical, err.msg);
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
            log(LogLevel.critical, err.msg);
            return [];
        }
    }

    if (resolve is null)
    {
        resolve = new Resolver(L);
    }

    return process(config, log, L, resManager, resolve);
}

string[] process(immutable Config config, LogDg log, LuaState L,
        ResourceManager resManager, Resolver resolve)
{
    string[] filenames;

    // A bad guess
    filenames.reserve(config.job.length);

    immutable(Canvas) canvas = canvasFromString(config.canvas);

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

        import std.zip : ZipArchive;

        ZipArchive archive;

        for (auto jobid = startJob; jobid <= endJob; ++jobid)
        {
            string outputFilename;

            if (config.enableUniqueFilenames)
            {
                import uniqueid : createUid;

                outputFilename = createUid(jobid, config, canvas);
            }
            else
            {
                outputFilename = jobid.to!string;
            }

            if (config.returnExistingFiles)
            {
                string[] existingFiles = existingFilenames(outputFilename, config.outdir, config.outputFormat);

                if (existingFiles.length > 0)
                {
                    return existingFiles;
                }
            }


            Sprite[] sprites;

            ImfResource bodyImf = null;

            if (isPlayer(jobid))
            {
                sprites = processPlayer(jobid, log, config, resolve, resManager, L, animationInterval, requestFrame);

                bodyImf = imfForJob(jobid, config.gender, resolve, resManager);
            }
            else
            {
                sprites = processNonPlayer(jobid, log, config, resolve, resManager, L, animationInterval, requestFrame);
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

            import draw : RawImage;
            import renderer : drawPlayer;

            void sortIndexDelegate(ref int[] index, uint frame)
            {
                int direction = config.action % 8;

                foreach (sprite; sprites)
                {
                    if (sprite.type == SpriteType.garment)
                    {
                        sprite.zIndex = zIndexForGarmentSprite(jobid, config.garment, config.action,
                                frame, config.gender, direction, L);
                    }
                    else if (sprite.type == SpriteType.playerhead && bodyImf !is null)
                    {
                        sprite.zIndex = zIndexForSprite(sprite, direction, config.action, frame, bodyImf);
                    }
                    else
                    {
                        sprite.zIndex = zIndexForSprite(sprite, direction);
                    }
                }

                import std.algorithm.sorting : makeIndex;

                makeIndex!"a.zIndex < b.zIndex"(sprites, index);
            }

            RawImage[] images = drawPlayer(sprites, config.action,
                    (requestFrame < 0) ? uint.max : requestFrame, &sortIndexDelegate, canvas);

            if (isBaby(jobid))
            {
                import renderer : applyBabyScaling;

                images.applyBabyScaling(0.75);
            }


            if (images.length > 0)
            {
                import imageformats.png : saveToPngFile;
                import std.file : mkdirRecurse, FileException, read;
                import std.format : format;
                import std.path : buildPath;
                import std.zip : ArchiveMember, CompressionMethod;

                bool shouldPutInZip = config.outputFormat == OutputFormat.zip;

                if (shouldPutInZip && archive is null)
                {
                    archive = new ZipArchive();
                }

                try
                {
                    mkdirRecurse(buildPath(config.outdir, outputFilename));
                }
                catch (FileException err)
                {
                    log(LogLevel.error, err.msg);
                    continue;
                }

                if (config.singleframes)
                {
                    foreach (i, image; images)
                    {
                        immutable basefilename = format("%d-%d.png", config.action, i);
                        auto filename = buildPath(config.outdir, outputFilename, basefilename);

                        saveToPngFile(image, filename);

                        filenames ~= filename;

                        if (shouldPutInZip)
                        {
                            putFileInZip(archive, filename, basefilename);
                        }
                    }
                }

                if (images.length > 1)
                {
                    import imageformats.png : saveToApngFile;

                    immutable basefilename = format("%d.png", config.action);
                    auto filename = buildPath(config.outdir, outputFilename, basefilename);

                    saveToApngFile(images, filename, (25 * animationInterval).to!ushort);

                    filenames ~= filename;

                    if (shouldPutInZip)
                    {
                        putFileInZip(archive, filename, basefilename);
                    }
                }
                else
                {
                    if (requestFrame < 0)
                    {
                        immutable basefilename = format("%d.png", config.action);
                        auto filename = buildPath(config.outdir, outputFilename, basefilename);

                        saveToPngFile(images[0], filename);

                        filenames ~= filename;

                        if (shouldPutInZip)
                        {
                            putFileInZip(archive, filename, basefilename);
                        }
                    }
                    else
                    {
                        immutable basefilename = format("%d-%d.png", config.action, requestFrame);
                        auto filename = buildPath(config.outdir, outputFilename, basefilename);
                        saveToPngFile(images[0], filename);

                        filenames ~= filename;

                        if (shouldPutInZip)
                        {
                            putFileInZip(archive, filename, basefilename);
                        }
                    }
                }

                if (shouldPutInZip)
                {
                    auto filename = buildPath(config.outdir, outputFilename, outputFilename ~ ".zip");
                    import std.file : write;

                    write(filename, archive.build());

                    filenames ~= filename;
                }
            }
        }
    }

    return filenames;
}

Sprite[] processNonPlayer(uint jobid, LogDg log, immutable Config config, Resolver resolve,
        ResourceManager resManager, ref LuaState L, out float interval, ref int requestFrame)
{
    bool overwriteFrame = false;

    const jobspritepath = resolve.nonPlayerSprite(jobid);
    if (jobspritepath.length == 0)
    {
        return [];
    }

    Sprite jobsprite;

    try
    {
        jobsprite = resManager.getSprite(jobspritepath);
        jobsprite.zIndex = 0;
    }
    catch (ResourceException err)
    {
        log(LogLevel.error, err.msg);
        return [];
    }

    auto sprites = [jobsprite];

    interval = jobsprite.act.action(config.action).interval;

    if (isMercenary(jobid))
    {
        const playerAction = intToPlayerAction(config.action);
        overwriteFrame = config.headdir != HeadDirection.all && config.frame < 0 &&
            (playerAction == PlayerAction.stand || playerAction == PlayerAction.sit);

        const gender = (jobid - 6017) <= 9 ? Gender.female : Gender.male;

        // Attach head to mercenary. Gender is derived from the job id
        auto headspritepath = resolve.playerHeadSprite(jobid, config.head, gender);
        if (headspritepath.length > 0)
        {
            auto headsprite = resManager.getSprite(headspritepath);
            headsprite.zIndex = 1;
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

        // Attach weapon
        if (config.weapon > 0)
        {
            auto weaponspritepath = resolve.weaponSprite(jobid, 1, gender);
            if (weaponspritepath.length > 0)
            {
                try
                {
                    auto weaponsprite = resManager.getSprite(weaponspritepath, SpriteType.weapon);
                    weaponsprite.typeOrder = 0;
                    weaponsprite.zIndex = 2;
                    sprites ~= weaponsprite;

                    if (jobid < 6017 || jobid > 6026)
                    {
                        // Weapon Slash only for lancer & swordsman
                        auto weaponslashsprite = resManager.getSprite(weaponspritepath ~ "_검광", SpriteType.weapon);
                        weaponslashsprite.typeOrder = 1;
                        weaponslashsprite.zIndex = 3;
                        sprites ~= weaponslashsprite;
                    }
                }
                catch (ResourceException err)
                {
                    log(LogLevel.warning, err.msg);
                }
            }
        }

        if (config.headgear.length > 0)
        {
            import std.algorithm : min;

            // Mercenaries can have 4 headgears
            const numHeadgears = min(4, config.headgear.length);

            for (auto h = 0; h < numHeadgears; ++h)
            {
                if (config.headgear[h] > 0)
                {
                    const headgearspritepath = resolve.headgearSprite(config.headgear[h], gender);
                    try
                    {
                        auto headgearsprite = resManager.getSprite(headgearspritepath, SpriteType.accessory);
                        headgearsprite.typeOrder = h;
                        headgearsprite.zIndex = 4 + h;
                        headgearsprite.parent(jobsprite);
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
                        log(LogLevel.warning, err.msg);
                    }
                }
            }
        }
    }
    if (requestFrame < 0)
    {
        foreach (sprite; sprites)
        {
            sprite.loadImagesOfAction(config.action);
        }
    }
    else
    {
        foreach (sprite; sprites)
        {
            if (sprite.type == SpriteType.accessory && sprite.act.frames(config.action).length > 3)
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

Sprite[] processPlayer(uint jobid, LogDg log, immutable Config config, Resolver resolve,
        ResourceManager resManager, ref LuaState L, out float interval, ref int requestFrame)
{
    import std.exception : ErrnoException;

    import std.stdio : writeln;

    uint direction = config.action % 8;

    const playerAction = intToPlayerAction(config.action);
    bool overwriteFrame = config.headdir != HeadDirection.all && config.frame < 0 &&
        (playerAction == PlayerAction.stand || playerAction == PlayerAction.sit);

    Sprite bodysprite;

    try
    {
        bodysprite = loadBodySprite(jobid, config.outfit, config.gender, resolve, resManager);
    }
    catch (ResourceException err)
    {
        log(LogLevel.error, err.msg);
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
        headsprite.parent(bodysprite);
        headsprite.headdir = config.headdir;
        sprites ~= headsprite;
    }
    catch (ResourceException err)
    {
        log(LogLevel.warning, err.msg);
    }

    if (config.weapon > 0)
    {
        const weaponspritepath = resolve.weaponSprite(jobid, config.weapon, config.gender);
        if (weaponspritepath.length > 0)
        {
            try
            {
                auto weaponsprite = resManager.getSprite(weaponspritepath, SpriteType.weapon);
                weaponsprite.typeOrder = 0;
                sprites ~= weaponsprite;

                // Weapon Slash
                auto weaponslashsprite = resManager.getSprite(weaponspritepath ~ "_검광", SpriteType.weapon);
                weaponslashsprite.typeOrder = 1;
                sprites ~= weaponslashsprite;
            }
            catch (ResourceException err)
            {
                log(LogLevel.warning, err.msg);
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
                sprites ~= shieldsprite;
            }
            catch (ResourceException err)
            {
                log(LogLevel.warning, err.msg);
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
                    headgearsprite.parent(bodysprite);
                    headgearsprite.headdir = config.headdir;

                    if (isDoram(jobid))
                    {
                        import luamanager : headgearOffsetForDoram;

                        const additionaloffset = headgearOffsetForDoram(config.headgear[h], direction, config.gender, L);
                        if (additionaloffset != additionaloffset.init)
                        {
                            headgearsprite.addOffsetToAttachPoint(config.action, config.frame, 0, -additionaloffset.x, -additionaloffset.y);
                        }
                    }

                    sprites ~= headgearsprite;

                    // Set to all frames if headgear has more frames
                    if (headgearsprite.act.frames(config.action).length > 3)
                    {
                        overwriteFrame = false;
                    }
                }
                catch (ResourceException err)
                {
                    log(LogLevel.warning, err.msg);
                }
            }
        }
    }

    if (config.garment > 0 && !isMadogear(jobid))
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
                garmentsprite.parent(bodysprite);
                sprites ~= garmentsprite;
            }
            catch (ResourceException err)
            {
                log(LogLevel.warning, err.msg);
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
                log(LogLevel.warning, err.msg);
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
                log(LogLevel.warning, err.msg);
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

    if (isPlayer(jobid) || isMercenary(jobid))
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

/// Throws ResourceException
private Sprite loadBodySprite(uint jobid, uint outfitid, const scope Gender gender,
        Resolver resolve, ResourceManager resManager)
{
    string bodyspritepath;
    Sprite bodysprite;

    bool useOutfit = false;

    if (outfitid > 0)
    {
        bodyspritepath = resolve.playerBodyAltSprite(jobid, gender, outfitid);
        if (bodyspritepath.length > 0)
        {
            try
            {
                bodysprite = resManager.getSprite(bodyspritepath, SpriteType.playerbody);
                useOutfit = true;
            }
            catch (ResourceException err)
            {
                // TODO show message to user?
            }
        }
    }

    if (!useOutfit)
    {
        bodyspritepath = resolve.playerBodySprite(jobid, gender);

        import std.exception : enforce;
        import std.format : format;

        enforce!ResourceException(bodyspritepath.length > 0,
                format("Couldn't resolve player body sprite for job %d and gender %s", jobid, gender));

        bodysprite = resManager.getSprite(bodyspritepath, SpriteType.playerbody);
    }

    return bodysprite;
}

private string[] existingFilenames(const scope string filename, const scope string outdir, OutputFormat outputFormat)
{
    import std.path : buildPath;
    import std.file : exists;

    const path = buildPath(outdir, filename);

    if (exists(path))
    {
        import std.array : array;
        import std.algorithm : each, filter, map;
        import std.file : dirEntries, SpanMode, FileException;
        import std.path : baseName;

        try
        {
            return dirEntries(path, "*.png", SpanMode.shallow, false)
                .filter!(entry => entry.isFile)
                .map!(entry => buildPath(path, baseName(entry.name)))
                .array;
        }
        catch (FileException err)
        {
            // Fall through
        }
    }

    return [];
}

private ImfResource imfForJob(uint jobid, const scope Gender gender,
        Resolver resolve, ResourceManager resManager)
{
    const imfName = resolve.imfName(jobid, gender);

    if (imfName.length > 0)
    {
        try
        {
            ImfResource imf = resManager.get!ImfResource(imfName);
            imf.load();

            return imf;
        }
        catch (ResourceException err)
        {
            // Fall through
        }
    }

    return null;
}

private void putFileInZip(ZipArchive archive, const scope string filename, const scope string nameInZip)
{
    import std.file : read;
    import std.zip : ArchiveMember, CompressionMethod;

    auto member = new ArchiveMember();
    member.compressionMethod = CompressionMethod.none;
    member.name = nameInZip;
    member.expandedData(cast(ubyte[]) read(filename));
    archive.addMember(member);
}

