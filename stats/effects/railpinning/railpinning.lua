function init()
    local duration = config.getParameter("duration", effect.duration());
    local velocity = duration // (math.pi * 2);
    local x = math.cos(duration);
    local y = math.sin(duration);
    sb.logInfo("%s %s %s %s", duration, velocity, x, y);
    mcontroller.addMomentum({x * velocity, y * velocity});
    effect.expire();
end

function update(dt)
    effect.expire()
end