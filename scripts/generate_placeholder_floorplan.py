#!/usr/bin/env python3
"""Generates a generic placeholder floor-plan grid image for the Manual Pin
screen. This is a synthetic grid, not a real project floor plan -- no real
floor plans exist yet for this build (see DECISIONS.md)."""

from PIL import Image, ImageDraw

WIDTH, HEIGHT = 1536, 1536
GRID_SPACING = 96
BG = (250, 248, 242, 255)
GRID_LINE = (200, 196, 184, 255)
MAJOR_LINE = (150, 145, 130, 255)
BORDER = (90, 86, 74, 255)
LABEL = (120, 115, 100, 255)

img = Image.new("RGBA", (WIDTH, HEIGHT), BG)
draw = ImageDraw.Draw(img)

for x in range(0, WIDTH + 1, GRID_SPACING):
    major = (x // GRID_SPACING) % 5 == 0
    draw.line([(x, 0), (x, HEIGHT)], fill=MAJOR_LINE if major else GRID_LINE, width=3 if major else 1)

for y in range(0, HEIGHT + 1, GRID_SPACING):
    major = (y // GRID_SPACING) % 5 == 0
    draw.line([(0, y), (WIDTH, y)], fill=MAJOR_LINE if major else GRID_LINE, width=3 if major else 1)

margin = GRID_SPACING * 2
draw.rectangle([margin, margin, WIDTH - margin, HEIGHT - margin], outline=BORDER, width=6)

# A couple of generic interior partition lines to read as a floor plan
# rather than a bare grid.
draw.line([(margin, HEIGHT * 0.45), (WIDTH * 0.6, HEIGHT * 0.45)], fill=BORDER, width=5)
draw.line([(WIDTH * 0.6, margin), (WIDTH * 0.6, HEIGHT * 0.45)], fill=BORDER, width=5)
draw.line([(WIDTH * 0.35, HEIGHT * 0.45), (WIDTH * 0.35, HEIGHT - margin)], fill=BORDER, width=5)

img.save("PlaceholderFloorplan.png")
print("wrote PlaceholderFloorplan.png", img.size)
