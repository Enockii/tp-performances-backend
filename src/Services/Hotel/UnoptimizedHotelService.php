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

/**
 * Une classe utilitaire pour récupérer les données des magasins stockés en base de données
 */
class UnoptimizedHotelService extends AbstractHotelService {

    use SingletonTrait;

    protected function __construct () {
        parent::__construct( new RoomService() );
    }


    /**
     * Récupère une nouvelle instance de connexion à la base de donnée
     *
     * @return PDO
     * @noinspection PhpUnnecessaryLocalVariableInspection
     */
    protected function getDB () : PDO {
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


    /**
     * Récupère toutes les meta données de l'instance donnée
     *
     * @param HotelEntity $hotel
     *
     * @return array
     * @noinspection PhpUnnecessaryLocalVariableInspection
     */
    protected function getMetas ( HotelEntity $hotel ) : array {
        /* TIMER */
        $timer = Timers::getInstance();
        $timerId = $timer->startTimer('getMetas');
        /* /TIMER */

        $stmt = $this->getDB()->prepare( "
        SELECT address1Data.meta_value AS address_1,
                  address2Data.meta_value AS address_2,
                  addressCityData.meta_value AS address_city,
                  addressZipData.meta_value AS address_zip,
                  addressCountryData.meta_value AS address_country,
                  CAST(geoLatData.meta_value AS float) AS geo_lat,
                  CAST(geoLngData.meta_value AS float) AS geo_lng,
                  phoneData.meta_value AS phone,
                  emailData.meta_value AS email,
                  coverImageData.meta_value AS coverImage
        
          FROM tp.wp_usermeta AS hotelData
          
          INNER JOIN tp.wp_usermeta AS address1Data
            ON hotelData.user_id = address1Data.user_id AND address1Data.meta_key = 'address_1'
                
          INNER JOIN tp.wp_usermeta AS address2Data
            ON hotelData.user_id = address2Data.user_id AND address2Data.meta_key = 'address_2'
        
          INNER JOIN tp.wp_usermeta AS addressCityData
            ON hotelData.user_id = addressCityData.user_id AND addressCityData.meta_key = 'address_city'
        
          INNER JOIN tp.wp_usermeta AS addressZipData
            ON hotelData.user_id = addressZipData.user_id AND addressZipData.meta_key = 'address_zip'
        
          INNER JOIN tp.wp_usermeta AS addressCountryData
            ON hotelData.user_id = addressCountryData.user_id AND addressCountryData.meta_key = 'address_country'
        
          INNER JOIN tp.wp_usermeta AS geoLatData
            ON hotelData.user_id = geoLatData.user_id AND geoLatData.meta_key = 'geo_lat'
        
          INNER JOIN tp.wp_usermeta AS geoLngData
            ON hotelData.user_id = geoLngData.user_id AND geoLngData.meta_key = 'geo_lng'
        
          INNER JOIN tp.wp_usermeta AS coverImageData
            ON hotelData.user_id = coverImageData.user_id AND coverImageData.meta_key = 'coverImage'
        
          INNER JOIN tp.wp_usermeta AS phoneData
            ON hotelData.user_id = phoneData.user_id AND phoneData.meta_key = 'phone'
        
          INNER JOIN tp.wp_usermeta AS emailData
            ON hotelData.user_id = emailData.user_id AND emailData.meta_key = 'email'
        
          WHERE hotelData.user_id = :hotelID
        
          GROUP BY hotelData.user_id;
        " );
        $stmt->execute([
            'hotelID' => $hotel->getId(),
        ]);

        $results = $stmt->fetch( PDO::FETCH_ASSOC );

        $metaDatas = [
            'address' => [
                'address_1' => $results['address_1'],
                'address_2' => $results['address_2'],
                'address_city' => $results['address_city'],
                'address_zip' =>  $results['address_zip'],
                'address_country' => $results['address_country'],
            ],
            'geo_lat' => $results['geo_lat'],
            'geo_lng' => $results['geo_lng'],
            'coverImage' => $results['coverImage'],
            'phone' => $results['phone'],
        ];

        /* TIMER */
        $timer->endTimer('getMetas', $timerId);
        /* /TIMER*/

        return $metaDatas;
    }


    /**
     * Récupère les données liées aux évaluations des hotels (nombre d'avis et moyenne des avis)
     *
     * @param HotelEntity $hotel
     *
     * @return array{rating: int, count: int}
     * @noinspection PhpUnnecessaryLocalVariableInspection
     */
    protected function getReviews ( HotelEntity $hotel ) : array {
        /* TIMER */
        $timer = Timers::getInstance();
        $timerId = $timer->startTimer('getReviews');
        /* /TIMER */

        // Récupère tous les avis d'un hotel
        $stmt = $this->getDB()->prepare( "SELECT ROUND(AVG(CAST(meta_value AS UNSIGNED INTEGER))) AS rating, COUNT(meta_value) AS ratingCount FROM wp_posts, wp_postmeta WHERE wp_posts.post_author = :hotelId AND wp_posts.ID = wp_postmeta.post_id AND meta_key = 'rating' AND post_type = 'review';" );
        $stmt->execute( [ 'hotelId' => $hotel->getId() ] );
        $reviews = $stmt->fetchAll( PDO::FETCH_ASSOC )[0];


        $output = [
            'rating' => intval($reviews['rating']),
            'count' => $reviews['ratingCount'],
        ];

        /* TIMER */
        $timer->endTimer('getReviews', $timerId);
        /* /TIMER*/

        return $output;
    }


    /**
     * Récupère les données liées à la chambre la moins chère des hotels
     *
     * @param HotelEntity $hotel
     * @param array{
     *   search: string | null,
     *   lat: string | null,
     *   lng: string | null,
     *   price: array{min:float | null, max: float | null},
     *   surface: array{min:int | null, max: int | null},
     *   rooms: int | null,
     *   bathRooms: int | null,
     *   types: string[]
     * }                  $args Une liste de paramètres pour filtrer les résultats
     *
     * @throws FilterException
     * @return RoomEntity
     */
    protected function getCheapestRoom ( HotelEntity $hotel, array $args = [] ) : RoomEntity
    {
        /* TIMER */
        $timer = Timers::getInstance();
        $timerId = $timer->startTimer('getCheapestRoom');
        /* /TIMER */

        /* Début de la requete avec le SELECT et tous les INNER JOIN
           pour rassembler toutes les données qui vont être nécessaires*/
        $query = "
        SELECT post.ID,
          post.post_title AS title,
          MIN(CAST(PriceData.meta_value AS float)) AS price,
          CAST(SurfaceData.meta_value AS int) AS surface,
          TypeData.meta_value AS types,
          CAST(BedroomsCountData.meta_value AS int) AS bedrooms,
          CAST(BathroomsCountData.meta_value AS int) AS bathrooms,
          CoverImageData.meta_value AS coverImage
        
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
      ";

        /* Suite de la requête : les WHERE, qui dépendent des critères de l'utilisateur donnés par $args[] */
        $whereClauses[] = "post.post_author = :hotelID AND post.post_type = 'room'";

        if (isset($args['surface']['min']))
            $whereClauses[] = 'SurfaceData.meta_value >= :surfaceMin';

        if (isset($args['surface']['max']))
            $whereClauses[] = 'SurfaceData.meta_value <= :surfaceMax';

        if (isset($args['price']['min']))
            $whereClauses[] = 'PriceData.meta_value >= :priceMin';

        if (isset($args['price']['max']))
            $whereClauses[] = 'PriceData.meta_value <= :priceMax';

        if (isset($args['rooms']))
            $whereClauses[] = 'BedroomsCountData.meta_value >= :roomsBed';

        if (isset($args['bathRooms']))
            $whereClauses[] = 'BathroomsCountData.meta_value >= :bathRooms';

        if (isset($args['types']) && !empty($args['types']))
            $whereClauses[] = "TypeData.meta_value IN('" . implode("', '", $args["types"]) . "')";


        /*On ajoute les clauses WHERE à la requête*/
        if ($whereClauses != [])
            $query .= " WHERE " . implode(' AND ', $whereClauses);

        $query .= " GROUP BY post.ID;";

        /*On récupère le PDOStatement*/
        $stmt = $this->getDB()->prepare($query);

        /*On récupère l'ID de l'hotel */
        $hotelID = $hotel->getId();
        $stmt->bindParam('hotelID', $hotelID, PDO::PARAM_INT);

        /*Bind des paramètres en fonction des clauses WHERE (donc des critères grâce à $args[])*/
        if (isset($args['surface']['min']))
            $stmt->bindParam('surfaceMin', $args['surface']['min'], PDO::PARAM_INT);

        if (isset($args['surface']['max']))
            $stmt->bindParam('surfaceMax', $args['surface']['max'], PDO::PARAM_INT);

        if (isset($args['price']['min']))
            $stmt->bindParam('priceMin', $args['price']['min'], PDO::PARAM_INT);

        if (isset($args['price']['max']))
            $stmt->bindParam('priceMax', $args['price']['max'], PDO::PARAM_INT);

        if (isset($args['rooms']))
            $stmt->bindParam('roomsBed', $args['rooms'], PDO::PARAM_INT);

        if (isset($args['bathRooms']))
            $stmt->bindParam('bathRooms', $args['bathRooms'], PDO::PARAM_INT);

        $stmt->execute();
        /*On regarde si la requête trouve bien une chambre correspond aux critères, sinon on génère une exception*/
        if(!($results = $stmt->fetch(PDO::FETCH_ASSOC)))
            throw new FilterException("Aucune chambre ne correspond aux critères.");

        /*Si la requête retourne un résultat : l'instancie*/
        $cheapestRoom = new RoomEntity();
        $cheapestRoom->setId($results['ID']);
        $cheapestRoom->setTitle($results['title']);
        $cheapestRoom->setPrice($results['price']);
        $cheapestRoom->setBathRoomsCount($results['bathrooms']);
        $cheapestRoom->setBedRoomsCount($results['bedrooms']);
        $cheapestRoom->setCoverImageUrl($results['coverImage']);
        $cheapestRoom->setSurface($results['surface']);
        $cheapestRoom->setType($results['types']);

        /* TIMER */
        $timer->endTimer('getCheapestRoom', $timerId);
        /* /TIMER*/

        return $cheapestRoom;
    }


    /**
     * Calcule la distance entre deux coordonnées GPS
     *
     * @param $latitudeFrom
     * @param $longitudeFrom
     * @param $latitudeTo
     * @param $longitudeTo
     *
     * @return float|int
     */
    protected function computeDistance ( $latitudeFrom, $longitudeFrom, $latitudeTo, $longitudeTo ) : float|int {
        return ( 111.111 * rad2deg( acos( min( 1.0, cos( deg2rad( $latitudeTo ) )
                * cos( deg2rad( $latitudeFrom ) )
                * cos( deg2rad( $longitudeTo - $longitudeFrom ) )
                + sin( deg2rad( $latitudeTo ) )
                * sin( deg2rad( $latitudeFrom ) ) ) ) ) );
    }


    /**
     * Construit un HotelEntity depuis un tableau associatif de données
     *
     * @throws Exception
     */
    protected function convertEntityFromArray ( array $data, array $args ) : HotelEntity {
        $hotel = ( new HotelEntity() )
            ->setId( $data['ID'] )
            ->setName( $data['display_name'] );

        // Charge les données meta de l'hôtel
        $metasData = $this->getMetas( $hotel );
        $hotel->setAddress( $metasData['address'] );
        $hotel->setGeoLat( $metasData['geo_lat'] );
        $hotel->setGeoLng( $metasData['geo_lng'] );
        $hotel->setImageUrl( $metasData['coverImage'] );
        $hotel->setPhone( $metasData['phone'] );

        // Définit la note moyenne et le nombre d'avis de l'hôtel
        $reviewsData = $this->getReviews( $hotel );
        $hotel->setRating( $reviewsData['rating'] );
        $hotel->setRatingCount( $reviewsData['count'] );

        // Charge la chambre la moins chère de l'hôtel
        $cheapestRoom = $this->getCheapestRoom( $hotel, $args );
        $hotel->setCheapestRoom($cheapestRoom);

        // Verification de la distance
        if ( isset( $args['lat'] ) && isset( $args['lng'] ) && isset( $args['distance'] ) ) {
            $hotel->setDistance( $this->computeDistance(
                floatval( $args['lat'] ),
                floatval( $args['lng'] ),
                floatval( $hotel->getGeoLat() ),
                floatval( $hotel->getGeoLng() )
            ) );

            if ( $hotel->getDistance() > $args['distance'] )
                throw new FilterException( "L'hôtel est en dehors du rayon de recherche" );
        }

        return $hotel;
    }


    /**
     * Retourne une liste d'entités qui peuvent être filtrées en fonction des paramètres donnés à $args
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
        $db = $this->getDB();
        $stmt = $db->prepare( "SELECT * FROM wp_users" );
        $stmt->execute();

        $results = [];
        foreach ( $stmt->fetchAll( PDO::FETCH_ASSOC ) as $row ) {
            try {
                $results[] = $this->convertEntityFromArray( $row, $args );
            } catch ( FilterException ) {
                // Des FilterException peuvent être déclenchées pour exclure certains hotels des résultats
            }
        }

        return $results;
    }
}