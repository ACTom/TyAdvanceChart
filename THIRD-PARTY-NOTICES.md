# Third-party notices

TyAdvanceChart itself is Modified LGPL. This file covers third-party material **bundled in the
source tree**, and what an application that ships it has to carry.

Nothing here asks anything of your **end users**: no on-screen attribution, no link back, no
notice displayed at run time. The obligation is only that the copyright and permission text
below travels with the binary — a copy of this file in your release package satisfies it.

---

## Apache ECharts example gallery

`examples/advchart/gallery/*.json` are the option trees of the official Apache ECharts
example gallery, converted from TypeScript to JSON by `tools/advchart-gallery/harvest.js`.
They are DATA, not code: each file is one chart configuration, and the conversion changes
only the notation. A function cannot survive the trip to JSON: each is written as a name
(`'@<example>.<key>'`), and the index lists them; three large ones are stored gzipped
(`*.json.gz`), and six whose data the page computes are stored without that data.

Three demo units carry code of the same examples, translated to Pascal under the same licence:
`examples/advchart/urenderitems.pas` (the custom series' `renderItem` functions),
`examples/advchart/ucallbacks.pas` (the pages' other functions: formatters, symbol sizes,
colours, label layouts, tooltip positions, animation delays, and the colour table
scatter-nutrients-matrix computes from its axes) and
`examples/advchart/ugenerated.pas` (the data generators of the six, including the
Perlin-noise helper heatmap-large carries, credited there to
https://github.com/josephg/noisejs).

Data and pictures of the same repository, used unmodified (the same licence; the repository
records no other source for them):

- `examples/advchart/data/winds.json.gz` -- `public/data-gl/asset/data/winds.json`, gzipped:
  the wind field custom-wind draws (ugenerated.pas makes the example's vectors from it).
- `examples/advchart/data/lines-airline-tables.json.gz` -- the airport names and each
  route's two airports out of `public/data/asset/data/flights.json`, gzipped: the tables
  lines-airline's tooltip reads (the harvest carries them).
- `examples/advchart/data/scatter-painter-choice-marker.json` -- the `marker.size`,
  `marker.color` and `marker.sizeref` of `public/data/asset/data/masterPainterColorChoice.json`,
  the part of that file scatter-painter-choice's two functions read (the page credits the
  data to Plot.ly).
- `examples/advchart/images/weather/sunny_128.png`, `cloudy_128.png`, `showers_128.png` --
  `public/data/asset/img/weather/`, the weather icons wind-barb, bar-rich-text and
  pie-rich-text show; the same three files are in apache/echarts itself (`test/data/weather/`),
  whose LICENSE lists no other terms for them.

Not included: `hill-Kilimanjaro.png` and `hill-Qomolangma.png` (pictorialBar-hill), photographs
for which the repository records no source; saved in `examples/advchart/images/` under their
names they are drawn.

They are used as a conformance corpus -- the point of the demo is to show what
`TTyAdvanceChart` does with an option written for ECharts, unmodified.

Source: https://github.com/apache/echarts-examples
Copyright The Apache Software Foundation, licensed under the Apache License 2.0.

```
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```

---

## d3-geo — `examples/advchart/ualbersusa.pas`

The demo's Albers USA projection (map-usa-projection) is a Pascal transcription of
`geoAlbersUsa` and the code it runs (`albers`, `conicEqualArea`, the projection's point stream
and rotation) of d3-geo 2.0.1 -- the version the gallery page loads. Upstream:
<https://github.com/d3/d3-geo>. The oracle that checks it installs the same version under
`tools/advchart-oracle` (`npm install`); nothing of d3 is shipped beyond the transcription.

```
Copyright 2010-2016 Mike Bostock
All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

* Neither the name of the author nor the names of contributors may be used to
  endorse or promote products derived from this software without specific prior
  written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```

---

## Maps for the AdvChart demo — `examples/advchart/maps/`

GeoJSON the gallery examples register with `echarts.registerMap` before they draw; the demo
registers them the same way (`examples/advchart/umaps.pas`). They are data, used unmodified
(`maps.json`, the name-to-file list, is ours).

- `USA.json`, `ch.geo.json`, `iceland.geo.json` — `public/data/asset/geo/` of
  <https://github.com/apache/echarts-examples>, copied as they are. `USA.json` is the US states
  file built from US Census Bureau boundaries (the example credits www.census.gov); the
  property names of the other two (`name` / `name_en`) are those of Natural Earth's admin-1
  layer, which is in the public domain. The repository records no other source for them.

Copyright The Apache Software Foundation, licensed under the Apache License 2.0 (the text is in
the gallery section above).

The SVG maps three gallery examples register (`echarts.registerMap(name, {svg})`), copied as
they are in `public/data/asset/geo/` of echarts-examples. They come from Wikimedia Commons, and
each keeps its own licence -- not the Apache License above:

- `Beef_cuts_France.svg` (geo-beef-cuts) -- "File:Beef cuts France.svg" by Pethrus, a
  derivative of "Brazilian_Cut.svg" by Mpontual,
  <https://commons.wikimedia.org/wiki/File:Beef_cuts_France.svg>, licensed under
  [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/) (or the GFDL 1.2 or later).
  Changed by the ECharts project: the cuts carry `name` attributes. Shared alike: this file
  stays under CC BY-SA 3.0.
- `Map_of_Iceland.svg` (geo-svg-scatter-simple, geo-svg-custom-effect) -- "File:Map of
  Iceland.svg" by Max Naylor, <https://commons.wikimedia.org/wiki/File:Map_of_Iceland.svg>,
  released into the public domain. Unchanged (the same 1834 x 1489 drawing).
- `Sicily_prehellenic_topographic_map.svg` (geo-svg-map) -- "File:Sicily prehellenic
  topographic map.svg" by Halibutt,
  <https://commons.wikimedia.org/wiki/File:Sicily_prehellenic_topographic_map.svg>, licensed
  under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/); it builds on "Sicily
  topographic map-blank.svg" by Sémhur (Ivan d'Hostingue, FAL / CC BY-SA) and "Maps
  template-en.svg" (CC BY-SA 3.0). Changed by the ECharts project: the routes and sites carry
  `name` attributes. Shared alike: this file stays under CC BY-SA 4.0. A relief of the island,
  no political lines.

Not included: maps that draw national borders -- `china`, `world` and `HK`, which a few examples
ask for. Borders are disputed, and some places require published maps to be reviewed (mainland
China, for one), so the demo ships none; it says so when an example needs one, and picks up a
file the user saves in `maps/` under the map's name. (`HK.json` would also be out on its own: its
fields are GADM's, whose terms forbid redistribution without permission.) Nor the other three
SVG maps of the gallery -- `flight-seats.svg` (geo-seatmap-flight),
`MacOdrum-LV5-floorplan-web.svg` (geo-svg-lines, a university library's floor plan) and
`ksia-ext-plan-min.svg` (geo-svg-traffic, an airport plan): echarts-examples records no source or
licence for them, so they are not redistributed here; saved in `maps/` under the map's name
(`<name>.svg`) they are picked up like the others.
