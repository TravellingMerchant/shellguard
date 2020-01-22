function damage(args)
  self.tookDamage = true
  animator.playSound("hurt")

  if args.sourceId and args.sourceId ~= 0 and not inTargets(args.sourceId) then
    table.insert(self.targets, args.sourceId)
  end
end