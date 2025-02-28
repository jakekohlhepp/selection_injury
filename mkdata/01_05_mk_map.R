## make map of divisions
library('sf')
library('data.table')
library('usmap')
library('ggplot2')
library('osmdata')
library('tidygeocoder')


working<-fread('mkdata/20170803_payworkers_comp/anonymized_data_073117.txt')
working<-unique(working[!is.na(`Div Cd`),c("Div Cd", "Assigned Div")])
setkey(working,`Div Cd` )
# i/s stands for intersection: https://ladotparking.org/wp-content/uploads/2018/04/Common-Abbreviations.pdf

write.csv(working,'mkdata/data/01_05_list_tofill.csv')
# info from https://geohub.lacity.org/datasets/ladot-engineering-districts/explore



shape <- read_sf(dsn = "mkdata/20250129_ladot_districts/", layer = "LADOT_Engineering_Districts")
# the valley regions are considered one in the payroll data
shape <-rbind(shape[shape$Dist!="East Valley" & shape$Dist!="West Valley",],st_union(shape[shape$Dist=="East Valley",],st_geometry(shape[shape$Dist=="West Valley",])))
shape[shape$Dist=="East Valley",]$Dist<-"Valley"

la_major <- getbb(place_name = "Los Angeles") %>%
  opq() %>%
  add_osm_feature(key = "highway", 
                  value = c("motorway", "primary", "secondary")) %>%
  osmdata_sf()




##

hqs<-fread('mkdata/data/01_05_list_complete.csv')
setnames(hqs, "clean_name", "Office")
hqs[, Office:=as.factor(Office)]
hqs<-unique(hqs[`Div Cd`>808 & Office!="Habitual Parking",c("Office", "location_parking_enforcement_office")])
hqs<-geocode(hqs, location_parking_enforcement_office)
hqs<-st_as_sf(hqs, coords = c("long","lat"), remove = FALSE)
st_crs(hqs)<-"EPSG:4326"
hqs<-st_transform(hqs,st_crs(shape))

street_plot <- ggplot() +
  geom_sf(data=shape,aes(fill=Dist), color=NA, alpha=0.8)+
  geom_sf(data = la_major$osm_lines,
          color = "black",alpha=0.3,
          size = 0.2)+  geom_point(data=hqs,
                                   aes(shape = Office, geometry = geometry),
                                   stat = "sf_coordinates"
          )+
  scale_shape_manual(values=1:nlevels(hqs$Office))+
  theme_bw()+theme(axis.title=element_blank(), axis.ticks=element_blank(), axis.text=element_blank())
# Print the plot
street_plot
