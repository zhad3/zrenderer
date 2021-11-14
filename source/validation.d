module validation;

bool isJobArgValid(const(string)[] jobids, int maxAmount = -1) pure @safe
{
    bool isValid = true;

    size_t jobcount = 0;

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
                jobcount++;
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

                jobcount += end == start ? 1 : (end-start);
            }
            catch (ConvException err)
            {
                isValid = false;
                break;
            }
        }
    }

    if (maxAmount >= 0 && jobcount > maxAmount)
    {
        isValid = false;
    }

    return isValid;
}

import std.regex : ctRegex;

immutable CanvasRegex = ctRegex!(`^([0-9]+)x([0-9]+)([\+\-][0-9]+)([\+\-][0-9]+)$`);

bool isCanvasArgValid(const scope string canvas) pure @safe
{
    if (canvas.length == 0 || canvas == string.init)
    {
        return true;
    }

    import std.regex : matchFirst;

    auto matchFound = matchFirst(canvas, CanvasRegex);

    if (matchFound.length == 5)
    {
        import std.conv : to, ConvException;
        try
        {
            matchFound[1].to!uint;
            matchFound[2].to!uint;
            matchFound[3].to!int;
            matchFound[4].to!int;
        }
        catch (ConvException err)
        {
            return false;
        }
    }
    else
    {
        return false;
    }

    return true;
}

