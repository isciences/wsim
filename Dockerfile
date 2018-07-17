FROM isciences/wsim-gitlabci:latest

ARG GIT_COMMIT=unknown
ARG WSIM_VERSION

LABEL git-commit=$GIT_COMMIT
ENV WSIM_GIT_COMMIT=$GIT_COMMIT

RUN test $WSIM_VERSION
ENV WSIM_VERSION=$WSIM_VERSION

RUN echo Building version $WSIM_VERSION from $GIT_COMMIT.

COPY wsim.io /wsim/wsim.io
WORKDIR /wsim/wsim.io
RUN sed -i 's/Version:.*/Version: '"$WSIM_VERSION"'/' DESCRIPTION
RUN echo ".WSIM_VERSION <- '$WSIM_VERSION'\n.WSIM_GIT_COMMIT <- '$GIT_COMMIT'" > R/version.R

RUN make install

COPY wsim.lsm /wsim/wsim.lsm
WORKDIR /wsim/wsim.lsm
RUN sed -i 's/Version:.*/Version: '"$WSIM_VERSION"'/' DESCRIPTION
RUN make install

COPY wsim.distributions /wsim/wsim.distributions
WORKDIR /wsim/wsim.distributions
RUN sed -i 's/Version:.*/Version: '"$WSIM_VERSION"'/' DESCRIPTION
RUN make install

COPY workflow /wsim/workflow
WORKDIR /wsim/workflow
RUN sed -i 's/__version__.*/__version__ = "'"$WSIM_VERSION"'"/' wsim_workflow/version.py
RUN make install

COPY utils /wsim/utils
COPY *.R /wsim/

COPY docs /wsim/docs
COPY Makefile /wsim/

WORKDIR /wsim
RUN make html

