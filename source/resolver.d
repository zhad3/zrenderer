module resolver;

import std.conv : to;
import luad.state : LuaState;
import config : Gender, toString;

bool isNPC(uint jobid) pure nothrow @safe @nogc
{
    return (jobid >= 45 && jobid < 1000) || (jobid >= 10_001 && jobid < 19_999);
}

bool isMercenary(uint jobid) pure nothrow @safe @nogc
{
    return jobid - 6017 <= 29;
}

bool isHomunculus(uint jobid) pure nothrow @safe @nogc
{
    return jobid - 6001 <= 51;
}

bool isMonster(uint jobid) pure nothrow @safe @nogc
{
    return jobid >= 1001 && jobid < 3999;
}

bool isPlayer(uint jobid) pure nothrow @safe @nogc
{
    return jobid < 45 || (jobid - 4001 < 280);
}

bool isDoram(uint jobid) pure nothrow @safe @nogc
{
    return jobid - 4217 <= 4;
}

bool isBaby(uint jobid) pure nothrow @safe @nogc
{
    if ((jobid >= 4023 && jobid <= 4045) || (jobid >= 4096 && jobid <= 4112) ||
            (jobid >= 4158 && jobid <= 4182) || jobid == 4191 || jobid == 4193 ||
            jobid == 4195 || jobid == 4196 || (jobid >= 4205 && jobid <= 4210))
    {
        return true;
    }
    return false;
}


class Resolver
{
    import std.path : buildPath;
    import std.string : representation;
    import std.uni : toLower;
    import std.utf : toUTF8;
    import zencoding.windows949 : fromWindows949;

    private
    {
        LuaState _lua;
        string[] _jobNamesPlayer;
        string[] _imfNames;
        string[] _jobNamesPalette;
        string[] _jobNamesWeapon;
        string[] _shieldNames;

        enum AdvancedJobIndex = 3950;
    }

    this(LuaState lua)
    {
        this._lua = lua;
        this.loadData();
    }

    private void loadData()
    {
        import std.file : readText;
        import std.string : splitLines;

        this._imfNames = readText("resolver_data/imf_names.txt").splitLines;
        this._jobNamesPlayer = readText("resolver_data/job_names.txt").splitLines;
        this._jobNamesPalette = readText("resolver_data/job_pal_names.txt").splitLines;
        this._jobNamesWeapon = readText("resolver_data/job_weapon_names.txt").splitLines;
        this._shieldNames = readText("resolver_data/shield_names.txt").splitLines;
    }

    string jobSpriteName(uint jobid)
    {
        if (isPlayer(jobid))
        {
            if (jobid > 4000)
            {
                jobid -= this.AdvancedJobIndex;
            }
            if (jobid < this._jobNamesPlayer.length)
            {
                return this._jobNamesPlayer[jobid];
            }
        }
        else
        {
            import luad.lfunction : LuaFunction;

            auto reqJobName = this._lua.get!LuaFunction("ReqJobName");
            string jobname = reqJobName.call!string(jobid);

            version (Windows)
            {
                return fromWindows949(jobname.representation).toUTF8.toLower;
            }
            else
            {
                import std.path : dirSeparator;
                import std.algorithm.iteration : substitute;

                return fromWindows949(jobname.representation).substitute("\\", dirSeparator).toUTF8.toLower;
            }
        }

        return "";
    }

    string imfName(uint jobid, Gender gender)
    {
        if (!isPlayer(jobid))
        {
            return "";
        }

        if (jobid > 4000)
        {
            jobid -= AdvancedJobIndex;
        }

        if (jobid >= this._imfNames.length)
        {
            return "";
        }

        auto imfName = this._imfNames[jobid].toLower;

        return imfName ~ "_" ~ gender.toString;
    }

    string playerBodySprite(uint jobid, Gender gender)
    {

        if (isPlayer(jobid))
        {
            auto jobname = this.jobSpriteName(jobid);
            if (isDoram(jobid))
            {
                return buildPath("도람족", "몸통", gender.toString, jobname ~ "_" ~ gender
                        .toString);
            }
            else
            {
                return buildPath("인간족", "몸통", gender.toString, jobname ~ "_" ~ gender
                        .toString);
            }
        }
        else
        {
            return "";
        }
    }

    string playerHeadSprite(uint jobid, uint headid, Gender gender)
    {
        string path;
        if (isDoram(jobid))
        {
            path = buildPath("도람족", "머리통", gender.toString, headid.to!string ~ "_" ~ gender
                    .toString);
        }
        else
        {
            path = buildPath("인간족", "머리통", gender.toString, headid.to!string ~ "_" ~ gender
                    .toString);
        }

        return path;
    }

    string nonPlayerSprite(uint jobid)
    {
        if (isPlayer(jobid))
        {
            return "";
        }

        auto jobname = this.jobSpriteName(jobid);

        if (jobname.length == 0)
        {
            return "";
        }

        if (isNPC(jobid))
        {
            return buildPath("npc", jobname);
        }
        else if (isMercenary(jobid))
        {
            return buildPath("인간족", "몸통", jobname);
        }
        else if (isHomunculus(jobid))
        {
            return buildPath("homun", jobname);
        }
        else if (isMonster(jobid))
        {
            return buildPath("몬스터", jobname);
        }

        return "";
    }

    string bodyPalette(uint jobid, uint paletteid, Gender gender)
    {
        if (!isPlayer(jobid))
        {
            return "";
        }

        bool doram = isDoram(jobid);

        if (jobid > 4000)
        {
            jobid -= AdvancedJobIndex;
        }
        if (jobid < this._jobNamesPalette.length)
        {
            if (doram)
            {
                return buildPath("도람족",
                        "body",
                        this._jobNamesPalette[jobid] ~ "_" ~ gender.toString ~ "_" ~ paletteid
                        .to!string);
            }
            else
            {
                return buildPath("몸",
                        this._jobNamesPalette[jobid] ~ "_" ~ gender.toString ~ "_" ~ paletteid
                        .to!string);
            }
        }

        return "";
    }

    string headPalette(uint jobid, uint headid, uint paletteid, Gender gender)
    {
        if (!isPlayer(jobid))
        {
            return "";
        }

        bool doram = isDoram(jobid);

        if (doram)
        {
            return buildPath("도람족",
                    "머리",
                    "머리" ~ headid.to!string ~ "_" ~ gender.toString ~ "_" ~ paletteid
                    .to!string);
        }
        else
        {
            return buildPath("머리",
                    "머리" ~ headid.to!string ~ "_" ~ gender.toString ~ "_" ~ paletteid
                    .to!string);
        }
    }

    string weaponSprite(uint jobid, uint weaponid, Gender gender)
    {
        if (!isPlayer(jobid))
        {
            return "";
        }

        bool doram = isDoram(jobid);

        if (jobid > 4000)
        {
            jobid -= AdvancedJobIndex;
        }
        if (jobid >= this._jobNamesWeapon.length)
        {
            return "";
        }

        version (Windows)
        {
            auto jobWeaponName = this._jobNamesWeapon[jobid];
        }
        else
        {
            import std.path : dirSeparator;
            import std.algorithm.iteration : substitute;

            auto jobWeaponName = this._jobNamesWeapon[jobid].substitute("\\", dirSeparator)
                .to!string;
        }

        string weaponName = "";
        import luad.lfunction : LuaFunction;

        auto reqWeaponName = this._lua.get!LuaFunction("ReqWeaponName");
        weaponName = fromWindows949(reqWeaponName.call!string(weaponid).representation).toUTF8.toLower;

        if (weaponName.length == 0)
        {
            auto getRealWeaponId = this._lua.get!LuaFunction("GetRealWeaponId");
            weaponid = getRealWeaponId.call!uint(weaponid);
            weaponName = fromWindows949(reqWeaponName.call!string(weaponid).representation).toUTF8.toLower;

            if (weaponName.length == 0)
            {
                weaponName = "_" ~ weaponid.to!string;
            }
        }

        if (weaponName.length == 0)
        {
            return "";
        }

        if (doram)
        {
            return buildPath("도람족",
                    jobWeaponName ~ "_" ~ gender.toString ~ weaponName);
        }
        else
        {
            return buildPath("인간족",
                    jobWeaponName ~ "_" ~ gender.toString ~ weaponName);
        }
    }

    string shieldSprite(uint jobid, uint shieldid, Gender gender)
    {
        if (!isPlayer(jobid))
        {
            return "";
        }

        string jobname = this.jobSpriteName(jobid);

        if (shieldid < this._shieldNames.length)
        {
            return buildPath("방패",
                    jobname,
                    jobname ~ "_" ~ gender.toString ~ this._shieldNames[shieldid]);
        }
        else
        {
            return buildPath("방패",
                    jobname,
                    jobname ~ "_" ~ gender.toString ~ "_" ~ shieldid.to!string ~ "_방패");
        }
    }

    string headgearSprite(uint headgearid, Gender gender)
    {
        import luad.lfunction : LuaFunction;

        auto reqAccName = this._lua.get!LuaFunction("ReqAccName");

        string headgearName = fromWindows949(reqAccName.call!string(headgearid)
                .representation).toUTF8.toLower;

        if (headgearName.length == 0)
        {
            return "";
        }

        return buildPath("악세사리", gender.toString, gender.toString ~ headgearName);
    }

    string garmentSprite(uint jobid, uint garmentid, Gender gender, bool checkEnglish = false)
    {
        if (!isPlayer(jobid))
        {
            return "";
        }

        auto jobname = this.jobSpriteName(jobid);

        import luad.lfunction : LuaFunction;

        auto reqRobSprName_v2 = this._lua.get!LuaFunction("ReqRobSprName_V2");

        string garmentName = fromWindows949(
                reqRobSprName_v2.call!string(garmentid, checkEnglish).representation)
            .toUTF8.toLower;

        if (garmentName.length == 0)
        {
            return "";
        }

        return buildPath("로브", garmentName, gender.toString, jobname ~ "_" ~ gender.toString);
    }
}
