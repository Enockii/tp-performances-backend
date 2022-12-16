<?php

namespace App\Services\Hotel;

use App\Common\PDOSingleton;
use App\Common\SingletonTrait;
use App\Common\Timers;
use App\Entities\HotelEntity;
use App\Entities\RoomEntity;
use App\Services\Reviews\APIReviewsService;
use App\Services\Reviews\CachedApiReviewsService;
use Exception;
use PDO;
use PDOStatement;
use Psr\Cache\InvalidArgumentException;

class ReworkedHotelService extends OneRequestHotelService
{
    use SingletonTrait;

    protected function __construct () {
        parent::__construct();
    }


    protected function getDB() : PDO
    {
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


    protected function buildQuery(array $args) : PDOStatement
    {
        /* TIMER */
        $timer = Timers::getInstance();
        $timerId = $timer->startTimer('GROSSEREQUETE');
        /* /TIMER */

        $query = "
              SELECT
                hotel.idHotel             AS hotelID,
                hotel.name                AS hotelName,
                hotel.mail                AS hotelEmail,
                hotel.address_1           AS hotelAddress_1,
                hotel.address_2           AS hotelAddress_2,
                hotel.address_city        AS hotelAddress_city,
                hotel.address_zip         AS hotelAddress_zip,
                hotel.address_country     AS hotelAddress_country,
                hotel.geo_lat             AS hotelGeo_lat,
                hotel.geo_lng             AS hotelGeo_lng,
                hotel.imageURL            AS hotelCoverImage,
                hotel.phone               AS hotelPhone,
                
                ROUND(AVG(review.review)) AS hotelRating,
                COUNT(review.review)      AS hotelRatingCount,
                
                room.idRoom               AS cheapestRID,
                room.title                AS cheapestRTitle,
                room.bathRoomsCount       AS cheapestRBathrooms,
                room.bedRoomsCount        AS cheapestRBedrooms,
                room.coverImageUrl        AS cheapestRCoverImage,
                room.surface              AS cheapestRSurface,
                room.type                 AS cheapestRTypes,
                MIN(room.price)           AS cheapestRPrice
              
            FROM hotels AS hotel
                
                INNER JOIN rooms AS room 
                    ON hotel.idHotel = room.idHotel
                INNER JOIN reviews AS review 
                    ON hotel.idHotel = review.idHotel
            
        ";

        /* Suite de la requête : conditions (WHERE), qui dépendent des critères de l'utilisateur, donnés par $args[] */
        $whereClauses = [];
        if ( isset( $args['lat'] ) && isset( $args['lng'] ) && isset( $args['distance'] ) ) {
            $whereClauses[] = '(111.111 * DEGREES(ACOS(LEAST(1.0, COS(RADIANS( hotel.geo_lat ))
                                * COS(RADIANS( :lat ))
                                * COS(RADIANS( hotel.geo_lng  - :lng ))
                                + SIN(RADIANS( hotel.geo_lat  ))
                                * SIN(RADIANS( :lat )))))) <= :distance';
        }

        if (isset($args['surface']['min']))
            $whereClauses[] = 'room.surface >= :surfaceMin';

        if (isset($args['surface']['max']))
            $whereClauses[] = 'room.surface <= :surfaceMax';

        if (isset($args['price']['min']))
            $whereClauses[] = 'room.price >= :priceMin';

        if (isset($args['price']['max']))
            $whereClauses[] = 'room.price <= :priceMax';

        if (isset($args['rooms']))
            $whereClauses[] = 'room.bedRoomsCount >= :roomsBed';

        if (isset($args['bathRooms']))
            $whereClauses[] = 'room.bathRoomsCount >= :bathRooms';

        if (isset($args['types']) && !empty($args['types']))
            $whereClauses[] = "room.type IN('" . implode("', '", $args["types"]) . "')";


        /*On ajoute les clauses WHERE à la requête*/
        if ($whereClauses != [])
            $query .= " WHERE " . implode(' AND ', $whereClauses);

        $query .= " GROUP BY hotel.idHotel;";

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
                ->setId($hotel['cheapestRID'])
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
     * Construit un HotelEntity depuis un tableau associatif de données
     *
     * @throws Exception
     * @throws InvalidArgumentException
     */
    protected function convertEntityAPI ( array $hotel ) : HotelEntity {

        /* TIMER */
        $timer = Timers::getInstance();
        $timerId = $timer->startTimer('ConvertEntityAPI');
        /* /TIMER */

        /* Résultat API Client reviews */
        $resultAPI = (new APIReviewsService)->get($hotel['hotelID'])['data'];
        //$resultAPI = (new CachedApiReviewsService())->get($hotel['hotelID']);

        $newHotel = ReworkedHotelService::convertEntityFromArray($hotel)
                        ->setRating( round($resultAPI['rating'] ))
                        ->setRatingCount( $resultAPI['count'] );

        /* TIMER */
        $timer->endTimer('ConvertEntityAPI', $timerId);
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
            $hotelEntities[] = $this->convertEntityAPI($hotel);
        }

        return $hotelEntities;
    }

}