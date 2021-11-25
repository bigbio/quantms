Installation and usage
==========================

The quantms is built using `Nextflow <https://www.nextflow.io>`_, a workflow tool to run tasks across multiple compute infrastructures in a very portable manner. It comes with docker containers making installation trivial and results highly reproducible.

The pre-requisites to run quantms are:

- `Nextflow <https://www.nextflow.io>`_
- Container or Package environment: `Docker <https://docs.docker.com/engine/installation/>`_, `Singularity <https://www.sylabs.io/guides/3.0/user-guide/>`_ or `Conda <https://conda.io/miniconda.html>`_


Installation steps
---------------------------

1. Installing `Nextflow <https://nf-co.re/usage/installation>`_

2. Install either `Docker <https://docs.docker.com/engine/installation/>`_ or `Singularity <https://www.sylabs.io/guides/3.0/user-guide/>`_ or `Conda <https://conda.io/miniconda.html>`_; see nf-core guidelines for basic `configuration profiles <https://nf-co.re/usage/configuration#basic-configuration-profiles>`_

3. Download the pipeline and test it on a minimal dataset with a single command:

.. code-block:: bash

   nextflow run bigbio/quantms -profile test,<docker/singularity/conda/institute>

.. note:: Please check `nf-core/configs <https://github.com/nf-core/configs#documentation>`_ to see if a custom config file to run nf-core pipelines already exists for your Institute. If so, you can simply use `-profile <institute>` in your command. This will enable either `docker` or `singularity` and set the appropriate execution settings for your local compute environment.

By using container's environments (e.g. Docker, Singularity or Conda) the user of quantms do not needs to install any dependency, software or tool manually. In addition, by using container enviroments the quantms guaranty the reproducibility/reliability of the analysis.

Usage
-------------------

Start running your own analysis!

.. code-block:: bash
   nextflow run bigbio\quantms -profile <docker/singularity/conda/institute> \
      --input '*.mzml' \
      --database 'myProteinDB.fasta' \
      --expdesign 'myDesign.sdrf.tsv'


See `usage docs <https://nf-co.re/quantms/usage>`_ for all of the available options when running the pipeline. Or configure the pipeline via
`nf-core launch <https://nf-co.re/launch>`_ from the web or the command line.

Contact Us
--------------------

|Get help on Slack|   |Report Issue| |Get help on GitHub Forum|

.. |Get help on Slack| image:: http://img.shields.io/badge/slack-nf--core%20%23quantms-4A154B?labelColor=000000&logo=slack
                   :target: https://nfcore.slack.com/channels/quantms

.. |Report Issue| image:: https://img.shields.io/github/issues/bigbio/quantms
                   :target: https://github.com/bigbio/quantms/issues

.. |Get help on GitHub Forum| image:: https://img.shields.io/badge/Github-Discussions-green
                   :target: https://github.com/bigbio/quantms/discussions
