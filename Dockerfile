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

COPY wsim.electricity /wsim/wsim.electricity
WORKDIR /wsim/wsim.electricity
RUN sed -i 's/Version:.*/Version: '"$WSIM_VERSION"'/' DESCRIPTION
RUN make install

COPY wsim.agriculture /wsim/wsim.agriculture
WORKDIR /wsim/wsim.agriculture
RUN sed -i 's/Version:.*/Version: '"$WSIM_VERSION"'/' DESCRIPTION
RUN make install

COPY wsim.gldas /wsim/wsim.gldas
WORKDIR /wsim/wsim.gldas
RUN sed -i 's/Version:.*/Version: '"$WSIM_VERSION"'/' DESCRIPTION
RUN make install

COPY docs /wsim/docs
WORKDIR /wsim

COPY Makefile /wsim/
RUN make html

COPY workflow /wsim/workflow
WORKDIR /wsim/workflow
RUN sed -i 's/__version__.*/__version__ = "'"$WSIM_VERSION"'"/' wsim_workflow/version.py
RUN make install

COPY utils /wsim/utils
COPY *.R /wsim/

WORKDIR /wsim

