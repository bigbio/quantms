Installation and usage
==========================

The quantms pipeline is built using `Nextflow <https://www.nextflow.io>`_, a workflow tool to run tasks across multiple compute infrastructures in a very portable manner.
It comes with docker/singularity/podman... containers making installation trivial and results highly reproducible.

The pre-requisites to run quantms are:

- `Nextflow <https://www.nextflow.io>`_
- Container or Package environment: `Docker <https://docs.docker.com/engine/installation/>`_, `Singularity <https://www.sylabs.io/guides/3.0/user-guide/>`_, Podman or `Conda <https://conda.io/miniconda.html>`_

.. note:: If you want to download locally the quantms workflow you should also install `git in your environment <https://git-scm.com/downloads>`_


Installation steps
---------------------------

1. Installing `Nextflow <https://nf-co.re/usage/installation>`_

2. Install either `Docker <https://docs.docker.com/engine/installation/>`_, `Singularity <https://www.sylabs.io/guides/3.0/user-guide/>`_, Podman, **or** `Conda <https://conda.io/miniconda.html>`_; see nf-core guidelines for basic `configuration profiles <https://nf-co.re/usage/configuration#basic-configuration-profiles>`_

3. Download the pipeline and test it on a minimal dataset with a single command:

You can get the pipeline in two different ways:

Manual download with git directly from github:

.. code-block:: bash
   
   git clone https://github.com/bigbio/quantms
   cd quantms

This will store a local copy of the pipeline, in order to be able to run it you should run the following command:

.. code-block:: bash

   nextflow run main.nf -c nextflow.config -profile test_lfq,<docker/singularity/conda/institute>

You can use nextflow to directly pull from the github:

.. code-block:: bash

   nextflow run bigbio/quantms -r dev -profile test_lfq,<docker/singularity/conda/institute>

.. note:: Please check `nf-core/configs <https://github.com/nf-core/configs#documentation>`_ to see if a custom config file to run nf-core pipelines already exists for your Institute. If so, you can simply use `-profile <institute>` in your command. This will enable either `docker` or `singularity` and set the appropriate execution settings for your local compute environment.

By using container's environments (e.g. Docker, Singularity or Conda) the user of quantms do not needs to install any dependency, software or tool manually. In addition, by using container environments the quantms guaranty the reproducibility/reliability of the analysis.

Usage
-------------------

Start running your own analysis!

.. code-block:: bash

   nextflow run bigbio\quantms -profile <docker/singularity/conda/institute> \
      --input '*.mzml' \
      --database 'myProteinDB.fasta' \
      --expdesign 'myDesign.sdrf.tsv'


See `usage docs <https://nf-co.re/quantms/usage>`_ for all of the available options when running the pipeline. Or configure the pipeline via
`nf-core launch <https://nf-co.re/launch/quantms>`_ from the web or the command line.

Contact Us
--------------------

|Get help on Slack|   |Report Issue| |Get help on GitHub Forum|

.. |Get help on Slack| image:: http://img.shields.io/badge/slack-nf--core%20%23quantms-4A154B?labelColor=000000&logo=slack
                   :target: https://nfcore.slack.com/channels/quantms

.. |Report Issue| image:: https://img.shields.io/github/issues/bigbio/quantms
                   :target: https://github.com/bigbio/quantms/issues

.. |Get help on GitHub Forum| image:: https://img.shields.io/badge/Github-Discussions-green
                   :target: https://github.com/bigbio/quantms/discussions
