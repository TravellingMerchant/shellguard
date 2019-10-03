function init()
  object.setInteractive(true)
end

function onInteraction(args)
  local chatOptions = config.getParameter("chatOptions", {})
  if #chatOptions > 0 then
    object.say(chatOptions[math.random(1, #chatOptions)],config.getParameter("chatTags",{}),config.getParameter("chatConfig",{}))
  end
end