Consensus of multiple search engines (ConsensusID)
==================================================

When multiple search engines are used ```--search_engines msgf,comet``` the results for each input file are
combined into one single identification file including the combination of all listed search engines.
To bring scores from different search engines to a comparable level, the posterior (error) probability output
from either Percolator or the distribution-fitting approach is used.
Finally, the OpenMS tool `ConsensusID <https://abibuilder.informatik.uni-tuebingen.de/archive/openms/Documentation/nightly/html/TOPP_ConsensusID.html>`_
is used to combine the results from different search engines. (TODO cite)
ConsensusID provides three algorithms to choose from, to score the PSM sequences from different engines per spectrum
(TODO mention param name):

- **best:** Just chooses the PSM with the highest probability. Here it is enough for each engine to provide only one top hit.
- **PEPMatrix:** Calculates a matrix of similarities across sequences of different engines to increase the weight for
  sequences that have a similar counterpart for another engine.
- **PEPIons:** Calculates a matrix of the number of shared matched ions across sequences of different engines to increase the weight for
  sequences that have a similar counterpart for another engine.

Additionally, minimal supports can be required (e.g., to enforce that a PSM was found by at least n engines).
TODO mention param.
