# Third-party notices

TyAdvanceChart itself is Modified LGPL. This file covers third-party material **bundled in the
source tree**, and what an application that ships it has to carry.

Nothing here asks anything of your **end users**: no on-screen attribution, no link back, no
notice displayed at run time. The obligation is only that the copyright and permission text
below travels with the binary — a copy of this file in your release package satisfies it.

---

## Apache ECharts and ZRender — `source/tyControls.AdvanceChart*`

Upstream: <https://github.com/apache/echarts> · ECharts 6.1.0, and
<https://github.com/ecomfe/zrender> · zrender 6.1.0, the version ECharts 6.1.0 depends on.

`TTyAdvanceChart` is a port of Apache ECharts 6.1 to Pascal. The units under `source/` whose
names start with `tyControls.AdvanceChart`, with their include files, carry code translated
from the TypeScript of ECharts and of zrender, the rendering library ECharts draws with: the
option model and its defaults, the coordinate systems, scales and layouts, the series and
components, the interactions and the animation, and zrender's paths, text, hit testing and
animators. Most of them name the upstream files they follow in their headers. A few are this
project's own code around the port; the heading covers the whole family all the same.

The option catalog comes from the same project. `source/tyControls.AdvanceChart.Catalog.pas`
and the option descriptions the design-time editor shows (`designtime/advchart-descs.json`,
packed into `designtime/tycontrols_advchart_desc.lrs`) are generated, through
`tools/advchart/extract-catalog.js` and `tools/advchart/catalog.json`, from the option schema
of Apache echarts-doc (<https://github.com/apache/echarts-doc>), and the descriptions are its
text. echarts-doc is under the same Apache License 2.0 and has no NOTICE file.

ECharts' LICENSE (below) names four of its files that embed code of d3.js, under d3's
BSD 3-Clause licence. The units ported from them carry that code too:
`tyControls.AdvanceChart.Treemap.pas` (`src/chart/treemap/treemapLayout.ts`),
`tyControls.AdvanceChart.Tree.pas` (`src/chart/tree/layoutHelper.ts`),
`tyControls.AdvanceChart.Graph.pas` (`src/chart/graph/forceHelper.ts`) and
`tyControls.AdvanceChart.Dataset.pas` (the `quantile` of `src/util/number.ts`). ECharts ships
that licence as `licenses/LICENSE-d3`; its text is word for word the one in the d3-geo section
below.

**You ship this if your program uses `TTyAdvanceChart`**, or any `tyControls.AdvanceChart*`
unit: the whole chart is the port.

The texts as upstream ships them: ECharts' `LICENSE` (the Apache License 2.0, then the list of
ECharts' subcomponents) and `NOTICE`, then zrender's `LICENSE` (BSD 3-Clause).

### Apache ECharts — `LICENSE`

```

                                 Apache License
                           Version 2.0, January 2004
                        http://www.apache.org/licenses/

   TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION

   1. Definitions.

      "License" shall mean the terms and conditions for use, reproduction,
      and distribution as defined by Sections 1 through 9 of this document.

      "Licensor" shall mean the copyright owner or entity authorized by
      the copyright owner that is granting the License.

      "Legal Entity" shall mean the union of the acting entity and all
      other entities that control, are controlled by, or are under common
      control with that entity. For the purposes of this definition,
      "control" means (i) the power, direct or indirect, to cause the
      direction or management of such entity, whether by contract or
      otherwise, or (ii) ownership of fifty percent (50%) or more of the
      outstanding shares, or (iii) beneficial ownership of such entity.

      "You" (or "Your") shall mean an individual or Legal Entity
      exercising permissions granted by this License.

      "Source" form shall mean the preferred form for making modifications,
      including but not limited to software source code, documentation
      source, and configuration files.

      "Object" form shall mean any form resulting from mechanical
      transformation or translation of a Source form, including but
      not limited to compiled object code, generated documentation,
      and conversions to other media types.

      "Work" shall mean the work of authorship, whether in Source or
      Object form, made available under the License, as indicated by a
      copyright notice that is included in or attached to the work
      (an example is provided in the Appendix below).

      "Derivative Works" shall mean any work, whether in Source or Object
      form, that is based on (or derived from) the Work and for which the
      editorial revisions, annotations, elaborations, or other modifications
      represent, as a whole, an original work of authorship. For the purposes
      of this License, Derivative Works shall not include works that remain
      separable from, or merely link (or bind by name) to the interfaces of,
      the Work and Derivative Works thereof.

      "Contribution" shall mean any work of authorship, including
      the original version of the Work and any modifications or additions
      to that Work or Derivative Works thereof, that is intentionally
      submitted to Licensor for inclusion in the Work by the copyright owner
      or by an individual or Legal Entity authorized to submit on behalf of
      the copyright owner. For the purposes of this definition, "submitted"
      means any form of electronic, verbal, or written communication sent
      to the Licensor or its representatives, including but not limited to
      communication on electronic mailing lists, source code control systems,
      and issue tracking systems that are managed by, or on behalf of, the
      Licensor for the purpose of discussing and improving the Work, but
      excluding communication that is conspicuously marked or otherwise
      designated in writing by the copyright owner as "Not a Contribution."

      "Contributor" shall mean Licensor and any individual or Legal Entity
      on behalf of whom a Contribution has been received by Licensor and
      subsequently incorporated within the Work.

   2. Grant of Copyright License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      copyright license to reproduce, prepare Derivative Works of,
      publicly display, publicly perform, sublicense, and distribute the
      Work and such Derivative Works in Source or Object form.

   3. Grant of Patent License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      (except as stated in this section) patent license to make, have made,
      use, offer to sell, sell, import, and otherwise transfer the Work,
      where such license applies only to those patent claims licensable
      by such Contributor that are necessarily infringed by their
      Contribution(s) alone or by combination of their Contribution(s)
      with the Work to which such Contribution(s) was submitted. If You
      institute patent litigation against any entity (including a
      cross-claim or counterclaim in a lawsuit) alleging that the Work
      or a Contribution incorporated within the Work constitutes direct
      or contributory patent infringement, then any patent licenses
      granted to You under this License for that Work shall terminate
      as of the date such litigation is filed.

   4. Redistribution. You may reproduce and distribute copies of the
      Work or Derivative Works thereof in any medium, with or without
      modifications, and in Source or Object form, provided that You
      meet the following conditions:

      (a) You must give any other recipients of the Work or
          Derivative Works a copy of this License; and

      (b) You must cause any modified files to carry prominent notices
          stating that You changed the files; and

      (c) You must retain, in the Source form of any Derivative Works
          that You distribute, all copyright, patent, trademark, and
          attribution notices from the Source form of the Work,
          excluding those notices that do not pertain to any part of
          the Derivative Works; and

      (d) If the Work includes a "NOTICE" text file as part of its
          distribution, then any Derivative Works that You distribute must
          include a readable copy of the attribution notices contained
          within such NOTICE file, excluding those notices that do not
          pertain to any part of the Derivative Works, in at least one
          of the following places: within a NOTICE text file distributed
          as part of the Derivative Works; within the Source form or
          documentation, if provided along with the Derivative Works; or,
          within a display generated by the Derivative Works, if and
          wherever such third-party notices normally appear. The contents
          of the NOTICE file are for informational purposes only and
          do not modify the License. You may add Your own attribution
          notices within Derivative Works that You distribute, alongside
          or as an addendum to the NOTICE text from the Work, provided
          that such additional attribution notices cannot be construed
          as modifying the License.

      You may add Your own copyright statement to Your modifications and
      may provide additional or different license terms and conditions
      for use, reproduction, or distribution of Your modifications, or
      for any such Derivative Works as a whole, provided Your use,
      reproduction, and distribution of the Work otherwise complies with
      the conditions stated in this License.

   5. Submission of Contributions. Unless You explicitly state otherwise,
      any Contribution intentionally submitted for inclusion in the Work
      by You to the Licensor shall be under the terms and conditions of
      this License, without any additional terms or conditions.
      Notwithstanding the above, nothing herein shall supersede or modify
      the terms of any separate license agreement you may have executed
      with Licensor regarding such Contributions.

   6. Trademarks. This License does not grant permission to use the trade
      names, trademarks, service marks, or product names of the Licensor,
      except as required for reasonable and customary use in describing the
      origin of the Work and reproducing the content of the NOTICE file.

   7. Disclaimer of Warranty. Unless required by applicable law or
      agreed to in writing, Licensor provides the Work (and each
      Contributor provides its Contributions) on an "AS IS" BASIS,
      WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
      implied, including, without limitation, any warranties or conditions
      of TITLE, NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A
      PARTICULAR PURPOSE. You are solely responsible for determining the
      appropriateness of using or redistributing the Work and assume any
      risks associated with Your exercise of permissions under this License.

   8. Limitation of Liability. In no event and under no legal theory,
      whether in tort (including negligence), contract, or otherwise,
      unless required by applicable law (such as deliberate and grossly
      negligent acts) or agreed to in writing, shall any Contributor be
      liable to You for damages, including any direct, indirect, special,
      incidental, or consequential damages of any character arising as a
      result of this License or out of the use or inability to use the
      Work (including but not limited to damages for loss of goodwill,
      work stoppage, computer failure or malfunction, or any and all
      other commercial damages or losses), even if such Contributor
      has been advised of the possibility of such damages.

   9. Accepting Warranty or Additional Liability. While redistributing
      the Work or Derivative Works thereof, You may choose to offer,
      and charge a fee for, acceptance of support, warranty, indemnity,
      or other liability obligations and/or rights consistent with this
      License. However, in accepting such obligations, You may act only
      on Your own behalf and on Your sole responsibility, not on behalf
      of any other Contributor, and only if You agree to indemnify,
      defend, and hold each Contributor harmless for any liability
      incurred by, or claims asserted against, such Contributor by reason
      of your accepting any such warranty or additional liability.

   END OF TERMS AND CONDITIONS

   APPENDIX: How to apply the Apache License to your work.

      To apply the Apache License to your work, attach the following
      boilerplate notice, with the fields enclosed by brackets "[]"
      replaced with your own identifying information. (Don't include
      the brackets!)  The text should be enclosed in the appropriate
      comment syntax for the file format. We also recommend that a
      file or class name and description of purpose be included on the
      same "printed page" as the copyright notice for easier
      identification within third-party archives.

   Copyright [yyyy] [name of copyright owner]

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.





========================================================================
Apache ECharts Subcomponents:

The Apache ECharts project contains subcomponents with separate copyright
notices and license terms. Your use of the source code for these
subcomponents is also subject to the terms and conditions of the following
licenses.

BSD 3-Clause (d3.js):
The following files embed [d3.js](https://github.com/d3/d3) BSD 3-Clause:
    `/src/chart/treemap/treemapLayout.ts`,
    `/src/chart/tree/layoutHelper.ts`,
    `/src/chart/graph/forceHelper.ts`,
    `/src/util/number.ts`
See `/licenses/LICENSE-d3` for details of the license.
```

### Apache ECharts — `NOTICE`

```
Apache ECharts
Copyright 2017-2026 The Apache Software Foundation

This product includes software developed at
The Apache Software Foundation (https://www.apache.org/).
```

### ZRender — `LICENSE`

```
BSD 3-Clause License

Copyright (c) 2017, Baidu Inc.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

* Neither the name of the copyright holder nor the names of its
  contributors may be used to endorse or promote products derived from
  this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```

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
