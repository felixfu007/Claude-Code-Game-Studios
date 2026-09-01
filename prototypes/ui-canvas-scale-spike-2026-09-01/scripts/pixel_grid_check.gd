extends RefCounted
## Reuses the project's own pixel-art integer-scale grid-integrity method
## (`.claude/docs/coding-standards.md`, screenshot evidence rule 4: "each source pixel must
## map to a clean NxN block of identical color, proving no resampling occurred") to test
## whether a bitmap-font-style texture, drawn under a given CanvasLayer counter-transform,
## renders as clean uniform blocks (integer combined scale) or ragged/uneven blocks
## (fractional combined scale — ordinary nearest-neighbor rounding artifacts, not blur,
## because the project runs Nearest filtering; the failure mode here is uneven block width,
## not blur).

## Creates a high-contrast alternating checkerboard Image, used as a stand-in for a real
## bitmap font glyph (Cubic 11 is not present as an installed/vendored asset in this repo;
## see README "已知簡化"). Any texture where adjacent pixels differ in color would work
## equally well for this specific measurement — what is being tested is block-size
## consistency after scaling, not font legibility.
static func make_checkerboard_texture(n: int) -> ImageTexture:
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in range(n):
		for x in range(n):
			var c: Color = Color.BLACK if (x + y) % 2 == 0 else Color.WHITE
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


## Scans one horizontal pixel row of a captured Image starting at (start_x, y) for
## `sample_width` pixels, and returns the list of consecutive-same-color run lengths.
static func measure_row_run_lengths(image: Image, start_x: int, y: int, sample_width: int) -> Array:
	var runs: Array = []
	var max_x: int = min(start_x + sample_width, image.get_width())
	if start_x >= max_x or y < 0 or y >= image.get_height():
		return runs
	var current_color: Color = image.get_pixel(start_x, y)
	var current_run: int = 1
	for x in range(start_x + 1, max_x):
		var c: Color = image.get_pixel(x, y)
		if c.is_equal_approx(current_color):
			current_run += 1
		else:
			runs.append(current_run)
			current_color = c
			current_run = 1
	runs.append(current_run)
	return runs


## Interior run lengths (dropping the first and last, which are legitimately partial when
## the sample window does not start exactly on a block boundary) must all match within
## `tolerance` pixels for the grid to count as "clean" — i.e. every fully-sampled source
## pixel produced the same on-screen block width.
static func is_grid_clean(run_lengths: Array, tolerance: int = 0) -> bool:
	if run_lengths.size() <= 2:
		return true
	var interior: Array = run_lengths.slice(1, run_lengths.size() - 1)
	if interior.is_empty():
		return true
	var first: int = interior[0]
	for r in interior:
		if absi(r - first) > tolerance:
			return false
	return true
