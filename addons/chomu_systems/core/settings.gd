class_name ChomuSettings
extends RefCounted
## Shared runtime switches read by every CHoMU system.

## Photosensitivity-safe mode: caps flicker to <= 3 Hz with shallow depth,
## limits chromatic aberration / FOV breathing and rate-limits brightness changes.
static var photosensitivity_safe: bool = false
## Global intensity multiplier for stress / scare effects (0..1).
static var effects_intensity: float = 1.0
## Max flashes per second allowed in safe mode (WCAG 2.3.1 general flash threshold).
const SAFE_MAX_FLASH_HZ := 3.0
