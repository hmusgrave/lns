# lns

A simple logarithmic number system

## Purpose

Logarithmic number systems can aid in CPU pipelining, speed up multiply/divide
heavy numerical calculations, and mildly increase precision (greatly for some
scenarios). This particular library _currently_ only provides a non-vectorized
16-bit implementation, which isn't particularly applicable to any of those
scenarios.

## Installation

Choose your favorite method for vendoring this code into your repository. I
think [git-subrepo](https://github.com/ingydotnet/git-subrepo) strikes a nicer
balance than git-submodules or most other alternatives.

When Zig gets is own builtin package manager we'll be available there as well.

```bash
git subrepo clone git+https://github.com/hmusgrave/lns.git [optional-subdir]
```

## Examples
```zig
const l16 = @import("lns.zig").l16;

test "something" {
    // 7 decimal bits
    const l16_7 = l16(7);

    const one = l16_7.from(1.0);
    const two = one.add(one);
    const pi = l16_7.from(@as(f32, 3.14159));

    try expect(pi.eql(two.mul(l16_7.from(1.570795))));
}
```

## Status
Contributions welcome. I'll check back on this repo at least once per month.
Currently targets Zig 0.10.*-dev.
