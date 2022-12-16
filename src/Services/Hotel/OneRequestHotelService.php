<?php

namespace App\Services\Hotel;

use App\Common\FilterException;
use App\Common\PDOSingleton;
use App\Common\SingletonTrait;
use App\Common\Timers;
use App\Entities\HotelEntity;
use App\Entities\RoomEntity;
use App\Services\Room\RoomService;
use Exception;
use PDO;
use PDOStatement;

/**
 * Une classe utilitaire pour récupérer les données des magasins stockés en base de données
 */
class OneRequestHotelService extends AbstractHotelService {

    use SingletonTrait;

    protected function __construct () {
        parent::__construct( new RoomService() );
    }


    protected function getDB() : PDO {
        /* TIMER */
        $timer = Timers::getInstance();
        $timerId = $timer->startTimer('getDB');
        /* /TIMER */


        $pdo = PDOSingleton::get();


        /* TIMER */
        $timer->endTimer('getDB', $timerId);
        /* /TIMER*/
        return $pdo;
    }


    protected function buildQuery(array $args) : PDOStatement {
        /* TIMER */
        $timer = Timers::getInstance();
        $timerId = $timer->startTimer('GROSSEREQUETE');
        /* /TIMER */


        $query = "
              SELECT 
                hotel.ID                                AS hotelID,
                hotel.display_name                      AS hotelName,
                address1Data.meta_value                 AS hotelAddress_1,
                address2Data.meta_value                 AS hotelAddress_2,
                addressCityData.meta_value              AS hotelAddress_city,
                addressZipData.meta_value               AS hotelAddress_zip,
                addressCountryData.meta_value           AS hotelAddress_country,
                CAST(geoLatData.meta_value AS float)    AS hotelGeo_lat,
                CAST(geoLngData.meta_value AS float)    AS hotelGeo_lng,
                phoneData.meta_value                    AS hotelPhone,
                emailData.meta_value                    AS hotelEmail,
                coverImageData.meta_value               AS hotelCoverImage,
                review.rating                           AS hotelRating,
                review.ratingCount                      AS hotelRatingCount,
                hotelRoomData.author                    AS cheapestRHotel,
                hotelRoomData.title                     AS cheapestRTitle,
                hotelRoomData.price                     AS cheapestRPrice,
                hotelRoomData.surface                   AS cheapestRSurface,
                hotelRoomData.types                     AS cheapestRTypes,
                hotelRoomData.bedrooms                  AS cheapestRBedrooms,
                hotelRoomData.bathrooms                 AS cheapestRBathrooms,
                hotelRoomData.coverImage                AS cheapestRCoverImage
            
              FROM tp.wp_users AS hotel
        
              INNER JOIN tp.wp_usermeta AS address1Data
                ON hotel.ID = address1Data.user_id AND address1Data.meta_key = 'address_1'
                    
              INNER JOIN tp.wp_usermeta AS address2Data
                ON hotel.ID = address2Data.user_id AND address2Data.meta_key = 'address_2'
            
              INNER JOIN tp.wp_usermeta AS addressCityData
                ON hotel.ID = addressCityData.user_id AND addressCityData.meta_key = 'address_city'
            
              INNER JOIN tp.wp_usermeta AS addressZipData
                ON hotel.ID = addressZipData.user_id AND addressZipData.meta_key = 'address_zip'
            
              INNER JOIN tp.wp_usermeta AS addressCountryData
                ON hotel.ID = addressCountryData.user_id AND addressCountryData.meta_key = 'address_country'
            
              INNER JOIN tp.wp_usermeta AS geoLatData
                ON hotel.ID = geoLatData.user_id AND geoLatData.meta_key = 'geo_lat'
            
              INNER JOIN tp.wp_usermeta AS geoLngData
                ON hotel.ID = geoLngData.user_id AND geoLngData.meta_key = 'geo_lng'
            
              INNER JOIN tp.wp_usermeta AS coverImageData
                ON hotel.ID = coverImageData.user_id AND coverImageData.meta_key = 'coverImage'
            
              INNER JOIN tp.wp_usermeta AS phoneData
                ON hotel.ID = phoneData.user_id AND phoneData.meta_key = 'phone'
            
              INNER JOIN tp.wp_usermeta AS emailData
                ON hotel.ID = emailData.user_id AND emailData.meta_key = 'email'
            
        
              INNER JOIN (
                SELECT 
                  post.post_author                             AS author,
                  post.post_title                              AS title,
                  CAST(PriceData.meta_value AS float)          AS price,
                  CAST(SurfaceData.meta_value AS int)          AS surface,
                  TypeData.meta_value                          AS types,
                  CAST(BedroomsCountData.meta_value AS int)    AS bedrooms,
                  CAST(BathroomsCountData.meta_value AS int)   AS bathrooms,
                  CoverImageData.meta_value                    AS coverImage
                
                  FROM tp.wp_posts AS post
                
                  INNER JOIN tp.wp_postmeta AS SurfaceData
                    ON post.ID = SurfaceData.post_id AND SurfaceData.meta_key = 'surface'
                
                  INNER JOIN tp.wp_postmeta AS PriceData
                    ON post.ID = PriceData.post_id AND PriceData.meta_key = 'price'
                
                  INNER JOIN tp.wp_postmeta AS TypeData
                    ON post.ID = TypeData.post_id AND TypeData.meta_key = 'type'
        
                  INNER JOIN tp.wp_postmeta AS BedroomsCountData
                    ON post.ID = BedroomsCountData.post_id AND BedroomsCountData.meta_key = 'bedrooms_count'
        
                  INNER JOIN tp.wp_postmeta AS BathroomsCountData
                    ON post.ID = BathroomsCountData.post_id AND BathroomsCountData.meta_key = 'bathrooms_count'
                
                  INNER JOIN tp.wp_postmeta AS CoverImageData
                    ON post.ID = CoverImageData.post_id AND CoverImageData.meta_key = 'coverImage'
        
              ) AS hotelRoomData ON hotel.ID = hotelRoomData.author
        
                  
              INNER JOIN (
                SELECT 
                  post_author                                                   AS author,
                  ROUND(AVG(CAST(wp_postmeta.meta_value AS UNSIGNED INTEGER)))  AS rating, 
                  COUNT(wp_postmeta.meta_value)                                 AS ratingCount
                
                FROM wp_usermeta, wp_posts, wp_postmeta
        
                WHERE wp_usermeta.user_id = wp_posts.post_author 
                  AND wp_posts.ID = wp_postmeta.post_id 
                  AND wp_postmeta.meta_key = 'rating' 
                  AND wp_posts.post_type = 'review'
        
                GROUP BY wp_posts.post_author
        
              ) AS review ON hotel.ID = review.author     
        
        ";

        /* Suite de la requête : conditions (WHERE), qui dépendent des critères de l'utilisateur, donnés par $args[] */
        $whereClauses = [];
        if ( isset( $args['lat'] ) && isset( $args['lng'] ) && isset( $args['distance'] ) ) {
            $whereClauses[] = '(111.111 * DEGREES(ACOS(LEAST(1.0, COS(RADIANS( CAST(geoLatData.meta_value AS float)))
                                * COS(RADIANS( :lat ))
                                * COS(RADIANS( CAST(geoLngData.meta_value AS float) - :lng ))
                                + SIN(RADIANS( CAST(geoLatData.meta_value AS float)))
                                * SIN(RADIANS( :lat )))))) <= :distance';
        }

        if (isset($args['surface']['min']))
            $whereClauses[] = 'surface >= :surfaceMin';

        if (isset($args['surface']['max']))
            $whereClauses[] = 'surface <= :surfaceMax';

        if (isset($args['price']['min']))
            $whereClauses[] = 'price >= :priceMin';

        if (isset($args['price']['max']))
            $whereClauses[] = 'price <= :priceMax';

        if (isset($args['rooms']))
            $whereClauses[] = 'bedrooms >= :roomsBed';

        if (isset($args['bathRooms']))
            $whereClauses[] = 'bathrooms >= :bathRooms';

        if (isset($args['types']) && !empty($args['types']))
            $whereClauses[] = "types IN('" . implode("', '", $args["types"]) . "')";


        /*On ajoute les clauses WHERE à la requête*/
        if ($whereClauses != [])
            $query .= " WHERE " . implode(' AND ', $whereClauses);

        $query .= " GROUP BY hotel.ID;";

        /*On récupère le PDOStatement*/
        $stmt = $this->getDB()->prepare($query);

        /* TIMER */
        $timer->endTimer('GROSSEREQUETE', $timerId);
        /* /TIMER*/

        return $stmt;
    }


    /**
     * Construit un HotelEntity depuis un tableau associatif de données
     *
     * @throws Exception
     */
    protected function convertEntityFromArray ( array $hotel ) : HotelEntity {

        /* TIMER */
        $timer = Timers::getInstance();
        $timerId = $timer->startTimer('ConvertEntity');
        /* /TIMER */

        // set les données de l'hôtel
        $newHotel = ( new HotelEntity() )
            ->setId( $hotel['hotelID'] )
            ->setName( $hotel['hotelName'] )
            ->setAddress( [
                'address_1' => $hotel['hotelAddress_1'],
                'address_2' => $hotel['hotelAddress_2'],
                'address_city' => $hotel['hotelAddress_city'],
                'address_zip' =>  $hotel['hotelAddress_zip'],
                'address_country' => $hotel['hotelAddress_country'],
            ] )
            ->setGeoLat( $hotel['hotelGeo_lat'] )
            ->setGeoLng( $hotel['hotelGeo_lng'] )
            ->setImageUrl( $hotel['hotelCoverImage'] )
            ->setPhone( $hotel['hotelPhone'] )

            // set la note moyenne et le nombre d'avis de l'hôtel
            ->setRating( $hotel['hotelRating'] )
            ->setRatingCount( $hotel['hotelRatingCount'] )

            // Charge la chambre la moins chère de l'hôtel
            ->setCheapestRoom( ( new RoomEntity() )
                ->setId($hotel['cheapestRHotel'])
                ->setTitle($hotel['cheapestRTitle'])
                ->setPrice($hotel['cheapestRPrice'])
                ->setBathRoomsCount($hotel['cheapestRBathrooms'])
                ->setBedRoomsCount($hotel['cheapestRBedrooms'])
                ->setCoverImageUrl($hotel['cheapestRCoverImage'])
                ->setSurface($hotel['cheapestRSurface'])
                ->setType($hotel['cheapestRTypes'])
            );

        /* TIMER */
        $timer->endTimer('ConvertEntity', $timerId);
        /* /TIMER*/

        return $newHotel;
    }





    /**
     * Retourne une liste de boutiques qui peuvent être filtrées en fonction des paramètres donnés à $args
     *
     * @param array{
     *   search: string | null,
     *   lat: string | null,
     *   lng: string | null,
     *   price: array{min:float | null, max: float | null},
     *   surface: array{min:int | null, max: int | null},
     *   bedrooms: int | null,
     *   bathrooms: int | null,
     *   types: string[]
     * } $args Une liste de paramètres pour filtrer les résultats
     *
     * @throws Exception
     * @return HotelEntity[] La liste des boutiques qui correspondent aux paramètres donnés à args
     */
    public function list ( array $args = [] ) : array {
        $results = $this->buildQuery($args);

        /*Bind des paramètres en fonction des clauses WHERE (donc des critères passés par $args[])*/
        if ( isset( $args['lat'] ) && isset( $args['lng'] ) && isset( $args['distance'] ) ) {
            $results->bindParam('lat', $args['lat']);
            $results->bindParam('lng', $args['lng']);
            $results->bindParam('distance', $args['distance']);
        }

        if ( isset($args['surface']['min']) )
            $results->bindParam('surfaceMin', $args['surface']['min'], PDO::PARAM_INT);

        if ( isset($args['surface']['max']) )
            $results->bindParam('surfaceMax', $args['surface']['max'], PDO::PARAM_INT);

        if ( isset($args['price']['min']) )
            $results->bindParam('priceMin', $args['price']['min'], PDO::PARAM_INT);

        if ( isset($args['price']['max']) )
            $results->bindParam('priceMax', $args['price']['max'], PDO::PARAM_INT);

        if ( isset($args['rooms']) )
            $results->bindParam('roomsBed', $args['rooms'], PDO::PARAM_INT);

        if ( isset($args['bathRooms']) )
            $results->bindParam('bathRooms', $args['bathRooms'], PDO::PARAM_INT);


        $results->execute();
        $results = $results->fetchAll( PDO::FETCH_ASSOC );

        $hotelEntities = [];

        foreach ($results as $hotel){
            $hotelEntities[] = $this->convertEntityFromArray($hotel);
        }

        return $hotelEntities;
    }
}