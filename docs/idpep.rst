Mixture-model-based re-scoring using probability distributions
==============================================================

OpenMS offers a fully parameterized unsupervised or semi-supervised distribution approach inspired by PeptideProphet
(TODO cite). The distribution families are currently fixed (Gumbel distribution for incorrect and Gaussian for correct PSMs).
It can be used as an alternative to Percolator to quantify uncertainty in the correctness of specific
PSMs (e.g., when Percolator cannot guess an initial direction due to insufficient amount of data). It will
calculate a posterior (error) probability for every PSM.
Currently, there is no discriminative function applied that combines several scores to improve the ranking, so
do not expect a boost in identifications.
