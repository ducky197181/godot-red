# Retro inspired 2D platformer made in Godot

- [Godot 4.4.1 Stable](https://godotengine.org/download/archive/4.4.1-stable/)
- Color palette is [Duel](https://lospec.com/palette-list/duel)

## Story

Game takes place in the near future, and attempts to replicate the often hammy narrative of older games.

An industrial sector is taken by an aggressive computer virus that corrupts wireless robotics and heavy machinery into wreaking havoc. Attempts at entering the sector have failed as the virus quickly takes over all smart gear and equipment within its area of effect.

They recruit Miguel Molina, also known as Red, for the mission. Red, having the ability to grow in size, can enter the perimeter unaffected and defend himself against the machinery.

Red, concerned about the safe evacuation of the people still inside the industrial sector, agrees, and equipped only with a low-frequency radio and a throwable disc to defend himself he sets out to find civilians and look for the source of the virus.

## Gameplay

Gameplay echoes old NES [Powerblade](https://www.youtube.com/watch?v=0s3TnIXJRaw) game with its boomerang based combat.

Player can throw these projectiles in 8 cardinal directions. Crouching let's the player throw the projectile one tile lower.

Waiting between throws gives the projectile further range, and repeatedly throwing works better at close range. The number of projectiles in flight concurrently may be limited at the start and expanded with pick-ups.

Player will have a health bar with similar granularity as in Mega Man series that had 28 health points.

Red can shift to his normal size, which allows him to enter spaces he couldn't at full height. These spaces may contain levers, civilians or item pick-ups. He is much more suspectible to damage in this state.

## Levels

This section contains preliminary concepts.

Game has four levels, or maps, and one of these is the final level. Player chooses the order they play these levels, even being able to start with the last and hardest level.

Each cleared level, however, reduces the challenge in others, by limiting certain enemies appearing or by other effects. A casual player could complete other maps to make the final level approachable, while others could choose to take on the final challenge in its hardest form.

## Programming guidelines

- Write logic with GDScript.
- Use groups and duck typing.
- Don't over-engineer.

## License

All art and assets included in this project are © ducky. Unless otherwise specified, these materials are copyrighted and may not be used, reproduced, or distributed without explicit permission.
