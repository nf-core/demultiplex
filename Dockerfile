FROM nfcore/base
LABEL authors="Chelsea Sawyer" \
      description="Docker image containing all requirements for nf-core/demultiplex pipeline"

COPY environment.yml /
RUN conda env create -f /environment.yml && conda clean -a
ENV PATH /opt/conda/envs/nf-core-demultiplex-1.0dev/bin:$PATH
