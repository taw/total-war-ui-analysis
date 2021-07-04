### Data structures (incomplete list, and only for some versions):

* `Version` block - always starts the file:

* * ASCII `Version`
* * 3 ASCII numbers

* `String` block:

* * uint16 size (can be zero for empty string)
* * that many ASCII bytes

* `Unicode` block:

* * uint16 size (can be zero for empty string)
* * that many UTF-16-LE codepoints

* `EventList` block

* * zero or more `String` blocks
* * one `String` block with value `events_end`

* `Image` block:

* * uint32 ID
* * `String` block path
* * uint32 xsize
* * uint32 ysize
* * uint32 unknown

* `ImageList` block:

* * uint32 count
* * that many `Image` blocks

* `ImagePathList` block:
* * uint32 count
* * that many `String` blocks with image paths

### Format - CML Version002

This format is not part of the main series.

These are `.cml` (Component Model List) files just being in same folder and with similar-looking headers, but otherwise unrelated, and appeared long after real UI file formats (Rome 2+).

Format is:

* `Version002` header
* any number of (until EOF):
* * `String` key
* * `String` value

### Format - Font Categories Version044

This format is not part of the main series.

These are `.fc` (Font Categories) files just being in same folder and with similar-looking headers, but otherwise unrelated.

It appears in Napoleon.

* `Version044` header
* any number of (until EOF):
* * `String`
* * `Uint32`
* * `String`
* * `Uint32`
* * `Uint32`
* * `BGRA32`

### Format - Font Categories Version050

This format is not part of the main series.

These are `.fc` (Font Categories) files just being in same folder and with similar-looking headers, but otherwise unrelated.

It appears in Shogun 2.

* `Version050` header
* any number of (until EOF):
* * `String`
* * `Uint32`
* * `String`
* * `Uint32`
* * `Uint32`
* * `Uint32`
* * `Uint32`
* * `BGRA32`

### Format - Font Categories Version051

This format is not part of the main series.

These are `.fc` (Font Categories) files just being in same folder and with similar-looking headers, but otherwise unrelated.

It appears in Rome 2.

* `Version051` header
* any number of (until EOF):
* * `String`
* * `Uint32`
* * `String`
* * `Uint32`
* * `Uint32`
* * `Uint32`
* * `Uint32`
* * `Uint32`
* * `BGRA32`

### Format - Font Categories Version052

This format is not part of the main series.

These are `.fc` (Font Categories) files just being in same folder and with similar-looking headers, but otherwise unrelated.

It appears in Attila, Thrones, and Warhammer 1.

* `Version052` header
* any number of (until EOF):
* * `String`
* * `Uint32`
* * `String`
* * `Uint32`
* * `Uint32`
* * `Uint32`
* * `Uint32`
* * `Uint32`
* * `BGRA32`
* * `String`
* * `Uint32`
* * `Uint32`
* * `Uint32`
* * `Uint32`

### Format - Font Categories Version053

This format is not part of the main series.

These are `.fc` (Font Categories) files just being in same folder and with similar-looking headers, but otherwise unrelated.

It appears in 3 Kingdoms, Troy, and Warhammer 2.

* `Version053` header
* any number of (until EOF):
* * `String`
* * `Uint32`
* * `String`
* * `Uint32`
* * `Uint32`
* * `Uint32`
* * `Uint32`
* * `Uint32`
* * `BGRA32`
* * `String`
* * `String`
* * `Uint32`
* * `Uint32`
* * `Uint32`
* * `Uint32`
