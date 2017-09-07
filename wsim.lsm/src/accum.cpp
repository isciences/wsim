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
static const FlowDirection OUT_NODATA = std::numeric_limits<FlowDirection>::min();

static const FlowDirection IN_EAST = 16;
static const FlowDirection IN_SOUTHEAST = 32;
static const FlowDirection IN_SOUTH = 64;
static const FlowDirection IN_SOUTHWEST = 128;
static const FlowDirection IN_WEST = 1;
static const FlowDirection IN_NORTHWEST = 2;
static const FlowDirection IN_NORTH = 4;
static const FlowDirection IN_NORTHEAST = 8;

NumericVector calculateFlowVector(int numRows, int numCols, const IntegerVector & directionBlockR, const NumericVector & weightBlockR);

static std::vector<int> makeDirectionArray(int numRawCols) {
  std::vector<int> direction(8);
  direction[0] = -1;              // West
  direction[1] = -numRawCols - 1; // NW
  direction[2] = -numRawCols;     // North
  direction[3] = -numRawCols + 1; // NE
  direction[4] = 1;               // East
  direction[5] = numRawCols + 1;  // SE
  direction[6] = numRawCols;      // South
  direction[7] = numRawCols - 1;  // SW

  return direction;
}

/**
 * Pad the flow direction block with extra rows and columns at each end.  This allows the processing to
 * ignore testing for the edges of the world.
 *
 * @param outFlowDir Block of output flow directions
 * @param numRows FlowQuantity of rows in domain
 * @param numCols FlowQuantity of columns in domain
 * @return Padded copy of output flow direction block
 */
static std::vector<FlowDirection> padOutwardDirBlock(const std::vector<FlowDirection> & outFlowDir,
                                                            int numRows,
                                                            int numCols) {
  const int numRawCols = numCols + 2;
  const int numRawRows = numRows + 2;

  std::vector<FlowDirection> rawOutDir(numRawRows * numRawCols, 0);

  int rawIndex = numRawCols + 1;
  int outIndex = 0;

  for (int row = 0; row < numRows; row++) {
    for (int col = 0; col < numCols; col++) {
      if (outFlowDir[outIndex] != OUT_NODATA) {
        rawOutDir[rawIndex] = outFlowDir[outIndex];
      } else {
        rawOutDir[rawIndex] = 0;
      }
      outIndex++;
      rawIndex++;
    }
    rawIndex = rawIndex + 2;
  }
  return rawOutDir;
}

/**
 * For each pixel, compute which cells drain _into_ that pixel.
 *
 * @param outDirBlock Padded block of output directions, produced by padOutwardDirBlock
 * @param numRows FlowQuantity of rows in domain
 * @param numCols FlowQuantity of columns in domain
 * @return Inward flow direction block
 */
static std::vector<FlowDirection> createInwardDirBlock(const std::vector<FlowDirection> & outDirBlock, int numRows, int numCols) {
  int numRawCols = numCols + 2;

  std::vector<FlowDirection> inwardFlowBlock(numCols * numRows, 0);
  std::vector<int> direction = makeDirectionArray(numRawCols);

  int pixelNum = 0;
  int outDirIndex = numRawCols + 1;
  for (int row = 0; row < numRows; row++) {
    for (int col = 0; col < numCols; col++) {
      int flag = 1;

      for (int compassDir = 0; compassDir < 8; compassDir++) {
        if ((outDirBlock[outDirIndex + direction[compassDir]] & flag) != 0) {
          inwardFlowBlock[pixelNum] += flag;
        }
        flag *= 2;
      }

      pixelNum = pixelNum + 1;
      outDirIndex = outDirIndex + 1;
    }

    outDirIndex = outDirIndex + 2;
  }

  return inwardFlowBlock;
}

/**
 * Find the top, or "headwater" pixels: those pixels into which no other pixels flow
 *
 * @param inwardFlowBlock A block or inward flow directions
 * @return A list of headwater pixel numbers
 */
static std::vector<PixelNumber> findTopElements(const std::vector<FlowDirection> inwardFlowBlock) {
  std::vector<PixelNumber> topElements;

  for (PixelNumber i = 0; i < inwardFlowBlock.size(); i++) {
    if (inwardFlowBlock[i] == 0) {
      topElements.push_back(i);
    }
  }

  return topElements;
}

/**
 * Perform a model iteration by processing the top elements.
 *
 * For each processed element, flow is added to a downstream pixel.  The upstream pixel is then
 * removed from the inwardFlowBlock for the downstream pixel.
 *
 * @param topElements A list of pixel numbers for top, or "headwater" pixels
 * @param outputFlowBlock A block of output flow directions for each pixel
 * @param inwardFlowBlock A block of input flow directions for each pixel
 * @param weightBlock A block of weights (e.g., runoff amounts) for each pixel
 * @param nodata NODATA value used for the weighting block
 * @param outwardFlowBlock A block of accumulated weights (e.g., runoff amounts) for each pixel
 * @param numRows FlowQuantity of rows in the domain
 * @param numCols FlowQuantity of columns in the domain
 *
 * @return An updated list of top, or "headwater" pixels
 */
static std::vector<PixelNumber> processTopElements(
    const std::vector<PixelNumber> & topElements,
    std::vector<FlowQuantity> & outputFlowBlock,
    std::vector<FlowDirection> & inwardFlowBlock,
    const std::vector<FlowQuantity> weightBlock,
    const std::vector<FlowDirection> & outwardFlowBlock,
    int numRows,
    int numCols) {

  std::vector<PixelNumber> newTopElements;

  for (PixelNumber pixNum : topElements) {
    int row = pixNum / numCols;
    int col = pixNum % numCols;
    int origRow = row;
    int origCol = col;
    int direction = outwardFlowBlock[pixNum];   // Where am I flowing to?

    if (direction != 0) {  // why not NODATA value here?
      FlowQuantity useWeight = std::isnan(weightBlock[pixNum]) ? 0 : weightBlock[pixNum];
      FlowQuantity useFlow = useWeight + outputFlowBlock[pixNum];

      switch (direction) {
        case OUT_EAST:
          col++;
          break;
        case OUT_SOUTHEAST:
          col++;
          row++;
          break;
        case OUT_SOUTH:
          row++;
          break;
        case OUT_SOUTHWEST:
          col--;
          row++;
          break;
        case OUT_WEST:
          col--;
          break;
        case OUT_NORTHWEST:
          col--;
          row--;
          break;
        case OUT_NORTH:
          row--;
          break;
        case OUT_NORTHEAST:
          col++;
          row--;
          break;
        case OUT_NODATA:
          // See https://gitlab.com/isciences/wsim/wsim2/issues/20
          // System.out.println("Lost flow into cell with undefined exit: " + useFlow);
          //if (useFlow > 0) {
          //  Rcout << "Losing " << useFlow << " at " << origRow << ", " << origCol << std::endl;
          //}
          break;
        default:
          Rcout << "Unexpected direction at " << origRow << ", " << origCol << ": " << direction << std::endl;
          throw "Unexpected direction";
      }

      // Handle flow that goes out of the extents of our grid
      // This behavior is not currently hit in production
      // Consider removing this, because it's not clear that the
      // behavior is desirable in all cases.
      // See https://gitlab.com/isciences/wsim/wsim2/issues/21
      if (row < 0) {
        // Flow went above the top of the map
        // Send it to the north pole?
        row = 0;
        col += numCols / 2;
      } else if (row >= numRows) {
        // Flow went below the bottom of the map
        // Send it to the south pole?
        row = numRows - 1;
        col += numCols / 2;
      }
      if (col < 0)
        // Wrap around the left
        col += numCols;
      else if (col >= numCols)
        // Wrap around the right
        col -= numCols;

      int receivingCell = col + (row * numCols);
      if (col >= 0 && col < numCols && row >= 0 && row < numRows) {
        outputFlowBlock[receivingCell] += useFlow;

        //if (row < 15 && useFlow > 0) {
        //  Rcout << "Flowing " << useFlow << " from " << origRow << ", " << origCol << " into " << row << ", " << col << std::endl;
        //  Rcout << "  It now has " << outputFlowBlock[receivingCell] << std::endl;
        //}
      }
      inwardFlowBlock[receivingCell] -= direction;  //Mark that we've flowed into this pixel

      // And if we're the last one to flow into this, it's a source for next iteration
      if (inwardFlowBlock[receivingCell] == 0) {
        newTopElements.push_back(receivingCell);
      }
    }
  }

  return newTopElements;
}

template<typename T>
static void printVector(std::string name, std::vector<T> v) {
  Rcout << name << std::endl;
  for (size_t i = 0; i < v.size(); i++) {
    Rcout << v[i] << " ";
  }
  Rcout << std::endl;
}

static std::vector<FlowQuantity> calculateFlow(
    int numRows,
    int numCols,
    std::vector<FlowDirection> & directionBlock,
    const std::vector<FlowQuantity> & weightBlock) {

  std::vector<FlowDirection> outwardFlowBlock = padOutwardDirBlock(directionBlock, numRows, numCols);
  std::vector<FlowDirection> inwardFlowBlock = createInwardDirBlock(outwardFlowBlock, numRows, numCols);

  std::vector<FlowQuantity> outputFlowBlock(directionBlock.size(), 0);

  int iteration = 0;
  std::vector<PixelNumber> topElements = findTopElements(inwardFlowBlock);

  while (!topElements.empty() && iteration < 50000) {
    topElements = processTopElements(topElements, outputFlowBlock, inwardFlowBlock, weightBlock, directionBlock, numRows, numCols);
    iteration++;
  }

  return outputFlowBlock;
}

static std::vector<FlowDirection> readDirections(const IntegerVector & directionBlock) {
  std::vector<FlowDirection> directions(directionBlock.size());

  for (int i = 0; i < directionBlock.size(); i++) {
    int val = directionBlock[i];

    if (val == NA_INTEGER) {
      val = OUT_NODATA;
    } else if (val < 0 || val > (int) std::numeric_limits<FlowDirection>::max()) {
      throw "Bad direction";
    }

    directions[i] = val;
  }

  return directions;
}

//' Accumulate flow, given flow directions and weights.
//'
//' @describeIn calculateFlow accumulate flow using matrix inputs/onputs
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
//'
//' @param weights a matrix of weights, representing the amount of flow originating at
//' each cell
//'
//' @return a matrix of accumulated flow values
//' @md
//' @export
// [[Rcpp::export]]
NumericMatrix calculateFlow(const IntegerMatrix & directions, const NumericMatrix & weights) {
  IntegerVector directionVector(directions.size());
  NumericVector weightVector(weights.size());
  int numRows = directions.nrow();
  int numCols = directions.ncol();

  // The flow accumulator is expecting a one-dimensional vector representing
  // concatenated rows of the input matrices.  Since the as.vector function in R
  // produces a vector of the concatenated columns, we construct the vectors
  // manually here.
  int index = 0;
  for (int i = 0; i < numRows; i++) {
    for (int j = 0; j < numCols; j++) {
      directionVector[index] = directions(i, j);
      weightVector[index] = weights(i, j);

      index++;
    }
  }

  NumericVector results = calculateFlowVector(numRows, numCols, directionVector, weightVector);

  NumericMatrix ret(numRows, numCols);
  for(index = 0; index < results.size(); index++) {
    int i = index / numCols;
    int j = index % numCols;
    ret(i, j) = results[index];
  }

  return ret;
}

//' @describeIn calculateFlow accumulate flow using vector inputs/outputs
//' @param numRows number of rows in original matrix
//' @param numCols number of columns in original matrix
//' @export
// [[Rcpp::export]]
NumericVector calculateFlowVector(
  int numRows,
  int numCols,
  const IntegerVector & directions,
  const NumericVector & weights) {

  std::vector<FlowDirection> directionBlock = readDirections(directions);
  std::vector<FlowQuantity> weightBlock = as<std::vector<FlowQuantity>>(weights);
  std::vector<FlowQuantity> flows = calculateFlow(numRows, numCols, directionBlock, weightBlock);

  // Add original weights to accumulated flow
  for (size_t i = 0; i < flows.size(); i++) {
    flows[i] += weights[i];
  }

  return wrap(flows);
}

