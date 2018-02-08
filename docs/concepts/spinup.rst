Model Spin-Up
=============

The land surface model "spin-up" process is used to generate a reasonable
initial state from which the model can proceed.
Because the model state variables are generally not available from an
independent source (amount of detained precipitation and snowmelt, for example),
the model is run iteratively to generate its own initial state.
The spin-up is performed in three phases, representing a combination of
techniques discussed in Rodell et al :cite:`Rodell:2005`.

Spin-Up Cycle #1
^^^^^^^^^^^^^^^^

In the first spin-up cycle, the model is initialized with a "garbage" initial
state.
It is then run into the future for an arbitrary 100 years with reasonable
forcing values (monthly climate norms).
While the resulting state is not an accurate representation of any point in time, it
represents a "reasonable" state that is no longer affected by the choice of values
in the initial state.

+--------------------------------------------------------------------------------+
| Spin-Up Cycle #1                                                               |
+====================+===========================================================+
| Duration           | 100 years                                                 |
+--------------------+-----------------------------------------------------------+
| Initial Condition  | "Garbage" initial state with detention variables          |
|                    | at zero, and soil moisture at 30% of capacity             |
|                    | (``spinup/initial_state.nc``)                             |
+--------------------+-----------------------------------------------------------+
| Forcing Data       | Monthly norm forcing calculate from period of             |
|                    | historical record (``spinup/climate_norm_forcing_MM.nc``) |
+--------------------+-----------------------------------------------------------+
| Result files       | Discarded                                                 |
+--------------------+-----------------------------------------------------------+
| State files        | Only final state saved (``spinup/final_state_norms.nc``)  |
+--------------------+-----------------------------------------------------------+

Spin-Up Cycle #2
^^^^^^^^^^^^^^^^

During the second phase of the spinup, the model state in January 1948 is
assumed to be the final state of the 100-year run performed in the first phase.
The model is then run with the full history of observed forcing data (i.e.,
January 1948 - present).
The model state after each iteration is stored, and per-month average states are
computed.

+--------------------------------------------------------------------------------+
| Spin-Up Cycle #2                                                               |
+====================+===========================================================+
| Duration           | Full historical period                                    |
+--------------------+-----------------------------------------------------------+
| Initial Condition  | Final state from cycle 1 (``spinup/final_state_norms.nc``)|
+--------------------+-----------------------------------------------------------+
| Forcing Data       | Historical forcing data                                   |
|                    | (``forcing/forcing_YYYYMM.nc``)                           |
+--------------------+-----------------------------------------------------------+
| Result files       | Discarded                                                 |
+--------------------+-----------------------------------------------------------+
| State files        | ``spinup/spinup_state_YYYYMM.nc``                         |
+--------------------+-----------------------------------------------------------+

Spin-Up Cycle #3
^^^^^^^^^^^^^^^^

In the final phase of the spinup, the model state in January 1948 is assumed to
be the mean state of all Januaries in the second phase.
The model is run with the full history of observed forcing data, and all model
results and states are retained.
A subset of the results from this spinup phase (e.g., 1950-2009) is used to fit
statistical distributions of model outputs.

+--------------------------------------------------------------------------------+
| Spin-Up Cycle #3                                                               |
+====================+===========================================================+
| Duration           | Full historical period                                    |
+--------------------+-----------------------------------------------------------+
| Initial Condition  | Mean January state from cycle 2                           |
|                    | (mean of ``spinup/spinup_state_YYYY01.nc``)               |
+--------------------+-----------------------------------------------------------+
| Forcing Data       | Historical forcing data                                   |
|                    | (``forcing/forcing_YYYYMM.nc``)                           |
+--------------------+-----------------------------------------------------------+
| Result files       | ``results/results_YYYYMM.nc``                             |
+--------------------+-----------------------------------------------------------+
| State files        | ``state/state_YYYYMM.nc``                                 |
+--------------------+-----------------------------------------------------------+

