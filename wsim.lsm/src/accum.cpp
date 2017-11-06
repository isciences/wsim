// [[Rcpp::plugins(cpp11)]]
#include <Rcpp.h>
using namespace Rcpp;

typedef int FlowDirection;
typedef double FlowQuantity;
typedef size_t PixelNumber;

static const FlowDirection OUT_EAST = 1;
static const FlowDirection OUT_SOUTHEAST = 2;
static const FlowDirection OUT_SOUTH = 4;
static const FlowDirection OUT_SOUTHWEST = 8;
static const FlowDirection OUT_WEST = 16;
static const FlowDirection OUT_NORTHWEST = 32;
static const FlowDirection OUT_NORTH = 64;
static const FlowDirection OUT_NORTHEAST = 128;
static const FlowDirection OUT_NONE = NA_INTEGER;

static const FlowDirection IN_EAST = 16;
static const FlowDirection IN_SOUTHEAST = 32;
static const FlowDirection IN_SOUTH = 64;
static const FlowDirection IN_SOUTHWEST = 128;
static const FlowDirection IN_WEST = 1;
static const FlowDirection IN_NORTHWEST = 2;
static const FlowDirection IN_NORTH = 4;
static const FlowDirection IN_NORTHEAST = 8;

struct Downstream {
  int row;
  int col;
  bool flows = true;

  void moveEast(int nCols, bool wrapX) {
    if (col == nCols - 1) {
      col = 0;
      flows = flows && wrapX;
    } else {
      col++;
    }
  }

  void moveWest(int nCols, bool wrapX) {
    if (col == 0) {
      col = nCols - 1;
      flows = flows && wrapX;
    } else {
      col--;
    }
  }

  void moveNorth(int nRows, int nCols, bool wrapY) {
    if (row == 0) {
      col = nCols - col - 1;
      flows = flows && wrapY;
    } else {
      row--;
    }
  }

  void moveSouth(int nRows, int nCols, bool wrapY) {
    if (row == nRows - 1) {
      col = nCols - col - 1;
      flows = flows && wrapY;
    } else {
      row++;
    }
  }

  Downstream(int row, int col) : row(row), col(col) {}
};

static Downstream flow(const IntegerMatrix & outDir, int i, int j, bool wrapX, bool wrapY) {
  Downstream ds{i, j};

  switch(outDir(i, j)) {
    case OUT_NORTH:
      ds.moveNorth(outDir.nrow(), outDir.ncol(), wrapY);
      break;
    case OUT_NORTHEAST:
      ds.moveNorth(outDir.nrow(), outDir.ncol(), wrapY);
      ds.moveEast(outDir.ncol(), wrapX);
      break;
    case OUT_EAST:
      ds.moveEast(outDir.ncol(), wrapX);
      break;
    case OUT_SOUTHEAST:
      ds.moveSouth(outDir.nrow(), outDir.ncol(), wrapY);
      ds.moveEast(outDir.ncol(), wrapX);
      break;
    case OUT_SOUTH:
      ds.moveSouth(outDir.nrow(), outDir.ncol(), wrapY);
      break;
    case OUT_SOUTHWEST:
      ds.moveSouth(outDir.nrow(), outDir.ncol(), wrapY);
      ds.moveWest(outDir.ncol(), wrapX);
      break;
    case OUT_WEST:
      ds.moveWest(outDir.ncol(), wrapX);
      break;
    case OUT_NORTHWEST:
      ds.moveNorth(outDir.nrow(), outDir.ncol(), wrapY);
      ds.moveWest(outDir.ncol(), wrapX);
      break;
    default:
      ds.flows = false;
      // Consider both OUT_NONE and 0 to be sink cells.
      // The flow direction matrix used for monthly WSIM runs
      // uses both.
      if (outDir(i, j) != OUT_NONE && outDir(i,j) != 0) {
        Rcout << "Invalid flow direction: " << outDir(i,j) << std::endl;
      }
  }

  return ds;
}

//' For each pixel, compute which cells drain _into_ that pixel.
//'
//' @inheritParams accumulate_flow
//' @return Matrix containing the summed direction values of all
//'         adjacent pixels that flow into this pixel. Value is
//'         zero if no adjacent pixels flow into this pixel (i.e,
//'         the pixel is a sink.)
//' @export
// [[Rcpp::export]]
IntegerMatrix create_inward_dir_matrix(const IntegerMatrix & directions, bool wrapX, bool wrapY) {
  IntegerMatrix inwardDirs(directions.nrow(), directions.ncol());

  for (int j = 0; j < directions.ncol(); j++) {
    for (int i = 0; i < directions.nrow(); i++) {
      Downstream ds = flow(directions, i, j, wrapX, wrapY);
      if (ds.flows) {
        inwardDirs(ds.row, ds.col) += directions(i, j);
      }
    }
  }

  return inwardDirs;
}

//' Accumulate flow, given flow directions and weights.
//'
//' @param directions a matrix of flow directions, where directions are represented
//' by the following values:
//'
//' * east: 1
//' * southeast: 2
//' * south: 4
//' * southwest: 8
//' * west: 16
//' * northwest: 32
//' * north: 64
//' * northeast: 128
//' * none (sink cell): NA
//'
//' @param weights a matrix of weights, representing the amount of flow originating at
//' each cell
//'
//' @param wrapX should flow exiting the X-limits of the model be routed to the other side?
//' @param wrapY should flow exiting the Y-limits of the model be routed to the other side?
//'
//' @return a matrix of accumulated flow values
//' @md
//' @export
// [[Rcpp::export]]
NumericMatrix accumulate_flow(const IntegerMatrix & directions, const NumericMatrix & weights, bool wrapX, bool wrapY) {
  IntegerMatrix inDirs = create_inward_dir_matrix(directions, wrapX, wrapY);
  NumericMatrix flows = clone(weights);

  std::vector<std::pair<int, int>> upstream;

  // Find all upstream pixels
  for (int j = 0; j < inDirs.ncol(); j++) {
    for (int i = 0; i < inDirs.nrow(); i++) {
      if (inDirs(i, j) == 0) {
        upstream.emplace_back(i, j);
      }
    }
  }

  int iteration = 0;
  while (!upstream.empty() && ++iteration < 50000) {
    std::vector<std::pair<int, int>> next_upstream;
    // Flow pixels
    for (auto pixel : upstream) {
      int i, j;
      std::tie(i, j) = pixel;

      auto ds = flow(directions, i, j, wrapX, wrapY);
      auto weight = flows(i, j);

      if (ds.flows) {
        if (std::isnan(weight)) {
          weight = 0;
        }

        if (std::isnan(flows(ds.row, ds.col))) {
          flows(ds.row, ds.col) = weight;
        } else {
          flows(ds.row, ds.col) += weight;
        }

        inDirs(ds.row, ds.col) -= directions(i, j);
        if (inDirs(ds.row, ds.col) == 0) {
          next_upstream.emplace_back(ds.row, ds.col);
        }
      }
    }
    upstream = std::move(next_upstream);
  }

  // Set the mask of the computed flows to be equal to the input flow directions
  for (int j = 0; j < flows.ncol(); j++) {
    for (int i = 0; i < flows.nrow(); i++) {
      if (std::isnan(directions(i, j))) {
        flows(i, j) = NA_REAL;
      }
    }
  }

  return flows;
}
