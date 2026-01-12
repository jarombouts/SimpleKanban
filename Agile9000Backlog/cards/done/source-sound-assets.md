---
title: Source and create sound assets
column: done
position: adm
created: 2026-01-10T12:00:00Z
modified: 2026-01-12T15:16:52Z
labels: [phase-3, assets, shared]
---

## Description

Find or create all 11 sound effects for TaskBuster9000. Sounds should be short, punchy, and satisfying. All sounds must be royalty-free or created fresh.

This is one of the larger tasks - audio sourcing can take time.

## Acceptance Criteria

- [ ] Acquire/create gong.mp3 (Asian temple gong hit)
- [ ] Acquire/create explosion.mp3 (punchy impact, not too loud)
- [ ] Acquire/create powerchord.mp3 (single guitar power chord)
- [ ] Acquire/create airhorn.mp3 (MLG/sports style)
- [ ] Acquire/create keyboard_clack.mp3 (mechanical keyboard)
- [ ] Acquire/create flush.mp3 (quick toilet flush)
- [ ] Acquire/create wilhelm_scream.mp3 (the classic)
- [ ] Acquire/create error_buzzer.mp3 (game show wrong answer)
- [ ] Acquire/create horror_sting.mp3 (orchestral stab)
- [ ] Acquire/create sad_trombone.mp3 (wah wah wah wahhh)
- [ ] Acquire/create chant.mp3 (group chanting for Jira Purge)
- [ ] Normalize all audio levels
- [ ] Trim silence from start/end
- [ ] Convert all to MP3 format, reasonable quality
- [ ] Keep total asset size under 2MB
- [ ] Verify all are royalty-free / CC0 / properly licensed

## Technical Notes

### Recommended Sources (Royalty-Free)

1. **Freesound.org** - Large CC library
2. **Zapsplat.com** - Free with attribution
3. **Mixkit.co** - Free, no attribution
4. **Pixabay.com/sound-effects** - Free, no attribution
5. **Create custom** - GarageBand/Logic for unique sounds

### Search Terms

| Sound | Search Terms |
|-------|--------------|
| gong | "gong hit", "temple bell", "asian gong" |
| explosion | "small explosion", "impact", "boom" |
| powerchord | "guitar chord", "power chord", "rock chord" |
| airhorn | "air horn", "sports horn", "mlg horn" |
| keyboard_clack | "keyboard typing", "mechanical keyboard", "key press" |
| flush | "toilet flush", "water flush" |
| wilhelm_scream | "wilhelm scream" (public domain) |
| error_buzzer | "wrong answer", "buzzer", "game show" |
| horror_sting | "horror stinger", "orchestral hit", "brass stab" |
| sad_trombone | "sad trombone", "wah wah", "failure sound" |
| chant | "crowd chanting", "ritual chant", "group chant" |

### Audio Specs

- Format: MP3
- Sample Rate: 44.1kHz
- Bit Rate: 128-192 kbps (balance quality/size)
- Duration: 0.5 - 3 seconds (except chant, which can be longer)
- Trim: No silence at start, minimal at end

### Processing Workflow

1. Download/record raw audio
2. Import into Audacity or similar
3. Trim silence
4. Normalize to -1dB peak
5. Apply subtle compression if needed
6. Export as MP3

## Platform Notes

MP3 works on both iOS and macOS via AVFoundation.

File: Place in `Resources/Sounds/default/`

## Licensing Notes

Keep a record of where each sound came from and its license. Create a `SOUND_CREDITS.md` file:

```markdown
# Sound Credits

## gong.mp3
- Source: Freesound.org
- Author: username
- License: CC0
- URL: https://freesound.org/...

## explosion.mp3
...
```