module resolver;

import std.conv : to;
import luad.state : LuaState;
import config : Gender, toString, MadogearType;

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
    return (jobid >= 1001 && jobid < 3999) || jobid >= 20_000;
}

bool isPlayer(uint jobid) pure nothrow @safe @nogc
{
    return jobid < 45 || (jobid - 4001 < 316);
}

bool isDoram(uint jobid) pure nothrow @safe @nogc
{
    return (jobid - 4217 <= 4) || jobid == 4308 || jobid == 4315;
}

bool isBaby(uint jobid) pure nothrow @safe @nogc
{
    if ((jobid >= 4023 && jobid <= 4045) || (jobid >= 4096 && jobid <= 4112) ||
            (jobid >= 4158 && jobid <= 4182) || jobid == 4191 || jobid == 4193 ||
            jobid == 4195 || jobid == 4196 || (jobid >= 4205 && jobid <= 4210) ||
            (jobid >= 4220 && jobid <= 4238) || jobid == 4241 || jobid == 4242 ||
            jobid == 4244 || jobid == 4247 || jobid == 4248)
    {
        return true;
    }
    return false;
}

bool isMadogear(uint jobid) pure nothrow @safe @nogc
{
    return jobid == 4086 || jobid == 4087 || jobid == 4112 || jobid == 4279;
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
        import std.string : splitLines, lineSplitter;
        import std.algorithm : map;
        import std.array : array;

        this._imfNames = readText("resolver_data/imf_names.txt").lineSplitter.map!(toLower).array;
        this._jobNamesPlayer = readText("resolver_data/job_names.txt").lineSplitter.map!(toLower).array;
        this._jobNamesPalette = readText("resolver_data/job_pal_names.txt").lineSplitter.map!(toLower).array;
        this._jobNamesWeapon = readText("resolver_data/job_weapon_names.txt").lineSplitter.map!(toLower).array;
        this._shieldNames = readText("resolver_data/shield_names.txt").lineSplitter.map!(toLower).array;
    }

    string jobSpriteName(uint jobid, MadogearType madogearType = MadogearType.robot)
    {
        if (isPlayer(jobid))
        {
            if (isMadogear(jobid) && madogearType == MadogearType.suit)
            {
                return alternativeMadogearJobName(jobid, madogearType);
            }

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

    string imfName(uint jobid, Gender gender, MadogearType madogearType = MadogearType.robot)
    {
        if (!isPlayer(jobid))
        {
            return "";
        }

        if (isMadogear(jobid) && madogearType == MadogearType.suit)
        {
            return alternativeMadogearJobName(jobid, madogearType) ~ "_" ~ gender.toString;
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

    string playerBodySprite(uint jobid, Gender gender, MadogearType madogearType = MadogearType.robot)
    {

        if (isPlayer(jobid))
        {
            auto jobname = this.jobSpriteName(jobid, madogearType);
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

    string playerBodyAltSprite(uint jobid, Gender gender, uint costumeid, MadogearType madogearType = MadogearType.robot)
    {

        if (isPlayer(jobid))
        {
            auto jobname = this.jobSpriteName(jobid, madogearType);
            auto costume = costumeid.to!string;
            if (isDoram(jobid))
            {
                return buildPath("도람족", "몸통", gender.toString, "costume_" ~ costume,
                        jobname ~ "_" ~ gender.toString ~ "_" ~ costume);
            }
            else
            {
                return buildPath("인간족", "몸통", gender.toString, "costume_" ~ costume,
                        jobname ~ "_" ~ gender.toString ~ "_" ~ costume);
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

    string bodyPalette(uint jobid, uint paletteid, Gender gender, MadogearType madogearType = MadogearType.robot)
    {
        if (!isPlayer(jobid))
        {
            return "";
        }

        if (isMadogear(jobid) && madogearType == MadogearType.suit)
        {
            return buildPath("몸",
                    alternativeMadogearJobName(jobid, madogearType) ~ "_" ~ gender.toString ~ "_" ~ paletteid
                    .to!string);
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

    string bodyAltPalette(uint jobid, uint paletteid, Gender gender, uint costumeid, MadogearType madogearType = MadogearType.robot)
    {
        if (!isPlayer(jobid))
        {
            return "";
        }

        if (isMadogear(jobid) && madogearType == MadogearType.suit)
        {
            return buildPath("몸",
                    "costume_" ~ costumeid.to!string,
                    alternativeMadogearJobName(jobid, madogearType) ~ "_" ~ gender.toString ~ "_" ~ paletteid.to!string ~ "_" ~ costumeid.to!string);
        }

        bool doram = isDoram(jobid);

        if (jobid > 4000)
        {
            jobid -= AdvancedJobIndex;
        }
        if (jobid < this._jobNamesPalette.length)
        {
            auto costume = costumeid.to!string;
            if (doram)
            {
                return buildPath("도람족",
                        "body",
                        "costume_" ~ costume,
                        this._jobNamesPalette[jobid] ~ "_" ~ gender.toString ~ "_" ~ paletteid.to!string ~ "_" ~ costume);
            }
            else
            {
                return buildPath("몸",
                        "costume_" ~ costume,
                        this._jobNamesPalette[jobid] ~ "_" ~ gender.toString ~ "_" ~ paletteid.to!string ~ "_" ~ costume);
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

    string weaponSprite(uint jobid, uint weaponid, Gender gender, MadogearType madogearType = MadogearType.robot)
    {
        const isPlayer = isPlayer(jobid);
        const isMercenary = isMercenary(jobid);

        if (!isPlayer && !isMercenary)
        {
            return "";
        }

        if (isPlayer)
        {
            const doram = isDoram(jobid);

            const isMadogear_ = isMadogear(jobid);
            const isAlternativeMadogear = isMadogear(jobid) && madogearType == MadogearType.suit;
            const madogearJobName = isAlternativeMadogear ? alternativeMadogearJobName(jobid, madogearType) : "";

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

                if (isAlternativeMadogear)
                {
                    import std.string : indexOf;
                    jobWeaponName = jobWeaponName[0 .. jobWeaponName.indexOf('\\') + 1] ~ madogearJobName;
                }
            }
            else
            {
                import std.path : dirSeparator;
                import std.algorithm.iteration : substitute;

                auto jobWeaponName = this._jobNamesWeapon[jobid].substitute("\\", dirSeparator).to!string;

                if (isAlternativeMadogear)
                {
                    import std.string : indexOf;
                    jobWeaponName = jobWeaponName[0 .. jobWeaponName.indexOf(dirSeparator) + 1] ~ madogearJobName;
                }
            }

            string weaponName = "";
            import luad.lfunction : LuaFunction;

            auto reqWeaponName = this._lua.get!LuaFunction("ReqWeaponName");
            weaponName = fromWindows949(reqWeaponName.call!string(weaponid).representation).toUTF8.toLower;

            if (weaponName.length == 0 && !isMadogear_)
            {
                auto getRealWeaponId = this._lua.get!LuaFunction("GetRealWeaponId");
                weaponid = getRealWeaponId.call!uint(weaponid);
                weaponName = fromWindows949(reqWeaponName.call!string(weaponid).representation).toUTF8.toLower;

                if (weaponName.length == 0)
                {
                    weaponName = "_" ~ weaponid.to!string;
                }
            }

            if (weaponName.length == 0 && !isMadogear_)
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
        else if (isMercenary)
        {
            if (jobid - 6017 <= 9)
            {
                // archer
                return buildPath("인간족", "용병", "활용병_활");
            }
            else if (jobid - 6027 <= 9)
            {
                // lancer
                return buildPath("인간족", "용병", "창용병_창");
            }
            else
            {
                // swordsman
                return buildPath("인간족", "용병", "검용병_검");
            }
        }

        return "";
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

    string garmentSprite(uint jobid, uint garmentid, Gender gender, bool checkEnglish = false,
            bool useFallback = false)
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

        if (useFallback)
        {
            return buildPath("로브", garmentName, garmentName);
        }
        else
        {
            return buildPath("로브", garmentName, gender.toString, jobname ~ "_" ~ gender.toString);
        }
    }

    // Alternative Madogear sprite, unfortunately hardcoded values
    string alternativeMadogearJobName(uint jobid, MadogearType type)
    {
        if (jobid == 4086 || jobid == 4087 || jobid == 4112)
        {
            // Mechanic
            return "마도아머";
        }
        else /* if (jobid == 4279)*/
        {
            // Meister
            return "meister_madogear2";
        }
    }
}

