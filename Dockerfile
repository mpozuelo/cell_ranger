FROM nfcore/base:1.9
LABEL authors="Marta Pozuelo del Rio" \
      description="Docker image containing all requirements for the mpozuelo/cell_ranger pipeline"

# Install the conda environment
COPY environment.yml /
RUN conda env create -f /environment.yml && conda clean -a

# Add conda installation dir to PATH (instead of doing 'conda activate')
ENV PATH /opt/conda/envs/mpozuelo-cell_ranger-1.0/bin:$PATH

# Dump the details of the installed packages to a file for posterity
RUN conda env export --name mpozuelo-cell_ranger-1.0 > mpozuelo-cell_ranger-1.0.yml


#install cell cellRanger
cd /opt
curl -o https://cf.10xgenomics.com/releases/cell-exp/cellranger-5.0.1.tar.gz?Expires=1613156369&Policy=eyJTdGF0ZW1lbnQiOlt7IlJlc291cmNlIjoiaHR0cHM6Ly9jZi4xMHhnZW5vbWljcy5jb20vcmVsZWFzZXMvY2VsbC1leHAvY2VsbHJhbmdlci01LjAuMS50YXIuZ3oiLCJDb25kaXRpb24iOnsiRGF0ZUxlc3NUaGFuIjp7IkFXUzpFcG9jaFRpbWUiOjE2MTMxNTYzNjl9fX1dfQ__&Signature=jwfXo83T2LCQdBM1QeCDI6kdvfs9oCRI8SRT5~CcvktmfJ4Gf7qZdycH0S1e~MlYtCW4OA80FvQfXYTCwtvdLKWr1PQEOBdFk-7ivSNaVyQI1DUBIlvWTEV9fIuEDBLxjiNVaY4JmlUYuzj87xFWntg01rX1FNMlhJlsmulCxCtS8UfqfauTPKlInjblv2cLGon2TSlgF9wAaeb0oqc8KNNmfU9tRj7x7skqJqPrCMzdo1yWpQrTDwEm-TRa9lsFFBNRCYN7AKBfVI1fnD1weFPYnyu1Kt7xL3-Tuc6h2ATuuBleziZ2PVD8dlW~9uLjV1k0OcRIKwP~82VqzgEfbg__&Key-Pair-Id=APKAI7S6A5RYOXBWRPDA
tar -xzvf cellranger-5.0.1.tar.gz
export PATH=/opt/cellranger-5.0.1:$PATH
