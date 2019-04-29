# Copyright (c) 2019 ISciences, LLC. # All rights reserved.
#
# WSIM is licensed under the Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License. You may
# obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

context('Crop codes')

test_that('SPAM abbreviations transposed correctly', {
  zip_contents <- '
  1337259  2018-12-17 10:40   spam2010v1r0_global_prod.geotiff/spam2010v1r0_global_production_acof_a.tif
  1709427  2018-12-17 10:40   spam2010v1r0_global_prod.geotiff/spam2010v1r0_global_production_bana_a.tif
  2153755  2018-12-17 10:40   spam2010v1r0_global_prod.geotiff/spam2010v1r0_global_production_barl_a.tif
  2182745  2018-12-17 10:40   spam2010v1r0_global_prod.geotiff/spam2010v1r0_global_production_bean_a.tif
  1909972  2018-12-17 10:41   spam2010v1r0_global_prod.geotiff/spam2010v1r0_global_production_cass_a.tif
  1538919  2018-12-17 10:41   spam2010v1r0_global_prod.geotiff/spam2010v1r0_global_production_chic_a.tif
  1438227  2018-12-17 10:42   spam2010v1r0_global_prod.geotiff/spam2010v1r0_global_production_cnut_a.tif
  1324796  2018-12-17 10:43   spam2010v1r0_global_prod.geotiff/spam2010v1r0_global_production_coco_a.tif
  1683901  2018-12-17 10:43   spam2010v1r0_global_prod.geotiff/spam2010v1r0_global_production_cott_a.tif
  1383102  2018-12-17 10:44   spam2010v1r0_global_prod.geotiff/spam2010v1r0_global_production_cowp_a.tif
  1863226  2018-12-17 10:44   spam2010v1r0_global_prod.geotiff/spam2010v1r0_global_production_grou_a.tif
  1474748  2018-12-17 10:44   spam2010v1r0_global_prod.geotiff/spam2010v1r0_global_production_lent_a.tif
  2927402  2018-12-17 10:44   spam2010v1r0_global_prod.geotiff/spam2010v1r0_global_production_maiz_a.tif
  2146855  2018-12-17 10:44   spam2010v1r0_global_prod.geotiff/spam2010v1r0_global_production_ocer_a.tif
  1519100  2018-12-17 10:44   spam2010v1r0_global_prod.geotiff/spam2010v1r0_global_production_ofib_a.tif
  1318746  2018-12-17 10:44   spam2010v1r0_global_prod.geotiff/spam2010v1r0_global_production_oilp_a.tif
  1833583  2018-12-17 10:44   spam2010v1r0_global_prod.geotiff/spam2010v1r0_global_production_ooil_a.tif
  2066942  2018-12-17 10:44   spam2010v1r0_global_prod.geotiff/spam2010v1r0_global_production_opul_a.tif
  1549138  2018-12-17 10:44   spam2010v1r0_global_prod.geotiff/spam2010v1r0_global_production_orts_a.tif
  1289765  2018-12-17 10:44   spam2010v1r0_global_prod.geotiff/spam2010v1r0_global_production_pige_a.tif
  1349946  2018-12-17 10:44   spam2010v1r0_global_prod.geotiff/spam2010v1r0_global_production_plnt_a.tif
  1543197  2018-12-17 10:44   spam2010v1r0_global_prod.geotiff/spam2010v1r0_global_production_pmil_a.tif
  2459960  2018-12-17 10:45   spam2010v1r0_global_prod.geotiff/spam2010v1r0_global_production_pota_a.tif
  1940795  2018-12-17 10:45   spam2010v1r0_global_prod.geotiff/spam2010v1r0_global_production_rape_a.tif
  1357245  2018-12-17 10:45   spam2010v1r0_global_prod.geotiff/spam2010v1r0_global_production_rcof_a.tif
  2157598  2018-12-17 10:45   spam2010v1r0_global_prod.geotiff/spam2010v1r0_global_production_rest_a.tif
  2130204  2018-12-17 10:45   spam2010v1r0_global_prod.geotiff/spam2010v1r0_global_production_rice_a.tif
  1539872  2018-12-17 10:45   spam2010v1r0_global_prod.geotiff/spam2010v1r0_global_production_sesa_a.tif
  1502330  2018-12-17 10:45   spam2010v1r0_global_prod.geotiff/spam2010v1r0_global_production_smil_a.tif
  2051055  2018-12-17 10:45   spam2010v1r0_global_prod.geotiff/spam2010v1r0_global_production_sorg_a.tif
  2137837  2018-12-17 10:45   spam2010v1r0_global_prod.geotiff/spam2010v1r0_global_production_soyb_a.tif
  1582391  2018-12-17 10:45   spam2010v1r0_global_prod.geotiff/spam2010v1r0_global_production_sugb_a.tif
  1727048  2018-12-17 10:45   spam2010v1r0_global_prod.geotiff/spam2010v1r0_global_production_sugc_a.tif
  1880336  2018-12-17 10:45   spam2010v1r0_global_prod.geotiff/spam2010v1r0_global_production_sunf_a.tif
  1852652  2018-12-17 10:46   spam2010v1r0_global_prod.geotiff/spam2010v1r0_global_production_swpo_a.tif
  1298232  2018-12-17 10:46   spam2010v1r0_global_prod.geotiff/spam2010v1r0_global_production_teas_a.tif
  2440252  2018-12-17 10:46   spam2010v1r0_global_prod.geotiff/spam2010v1r0_global_production_temf_a.tif
  1595180  2018-12-17 10:46   spam2010v1r0_global_prod.geotiff/spam2010v1r0_global_production_toba_a.tif
  2296846  2018-12-17 10:46   spam2010v1r0_global_prod.geotiff/spam2010v1r0_global_production_trof_a.tif
  2852117  2018-12-17 10:46   spam2010v1r0_global_prod.geotiff/spam2010v1r0_global_production_vege_a.tif
  2650652  2018-12-17 10:46   spam2010v1r0_global_prod.geotiff/spam2010v1r0_global_production_whea_a.tif
  1438749  2018-12-17 10:46   spam2010v1r0_global_prod.geotiff/spam2010v1r0_global_production_yams_a.tif
  '
  
  expect_equal(sort(substr(read.table(text=zip_contents, stringsAsFactors=FALSE)[, 4], 65, 68)),
               sort(wsim.agriculture::spam_crops$spam_abbrev))
})

test_that('Crop code cross-references are correct', {
  # Avoid importing magrittr pipe
  merged <- 
    dplyr::summarise(
      dplyr::group_by(
        dplyr::inner_join(
          dplyr::inner_join(wsim.agriculture::wsim_crops, mirca_crops),
          spam_crops),
        wsim_id, wsim_name, mirca_name),
      spam_names=paste(spam_name, collapse=', '))
                      
  expect_equal(19, nrow(merged))
  expect_false(any(is.na(merged$mirca_name)))
  expect_false(any(is.na(merged$spam_names)))
})
