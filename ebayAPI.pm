################################################################################ 
    # 
    # File: .......................... ebayAPI.pm 
    # 
    # Description... 
    # 
    # This module is strictly used for listing, update and delete items on eBay. 
    # 
    # Author .......................... Michael Deng 
################################################################################ 
 
# Package Declaration 
# ------------------------------------------------------------------------------ 
        package eBayAPI; 
 
# Required Includes 
# ------------------------------------------------------------------------------ 
        use strict; 
        use warnings; 
        use Data::Dumper;    #need to be removed once development is complete 
 
        # module to convert variable to lower case 
        use Hash::Case::Lower; 
 
        # eBay API call class 
        use eBay::API::XML::Call::AddItem; 
        use eBay::API::XML::Call::ReviseItem; 
        use eBay::API::XML::Call::VerifyAddItem; 
        use eBay::API::XML::Call::GetSuggestedCategories; 
        use eBay::API::XML::Call::EndItem; 
 
        # Datatype class - it acts as a container for api call data 
        use eBay::API::XML::DataType::ItemType; 
        use eBay::API::XML::DataType::CategoryType; 
        use eBay::API::XML::DataType::ShippingServiceOptionsType; 
        use eBay::API::XML::DataType::PictureDetailsType; 
        use eBay::API::XML::DataType::Enum::EndReasonCodeType; 
 
# Variable Declarations 
# ------------------------------------------------------------------------------ 
# Globals 
 
        our $VERSION = "0.1"; 
 
        sub new { 
 
            my $class = shift; 
 
            my $self = {@_}; 
 
            bless( $self, $class ); 
 
            return $self; 
 
        } 
 
        # Assigning eBay user credentials 
        sub _account { 
 
            # Get all arguments passed in 
            my ( $pCall, $self ) = @_; 
 
        # Set local variables to strings been passed in to appropriate variables 
            my $apiUrl    = $self->{apiUrl}; 
            my $devID     = $self->{devID}; 
            my $appID     = $self->{appID}; 
            my $cerID     = $self->{certID}; 
            my $authToken = $self->{authToken}; 
            my $siteID    = $self->{siteID}; 
            my $complvl   = $self->{complvl}; 
 
            # Set eBay user credentials to appropriate variable 
            $pCall->setApiUrl($apiUrl); 
            $pCall->setDevID($devID); 
            $pCall->setAppID($appID); 
            $pCall->setCertID($cerID); 
            $pCall->setAuthToken($authToken); 
            $pCall->setSiteID($siteID); 
            $pCall->getCompatibilityLevel($complvl); 
 
        } 
 
        sub find_categories { 
 
            my $self = shift; 
 
            my $query = shift; 
 
            my $pCall = eBay::API::XML::Call::GetSuggestedCategories->new(); 
 
            _account( $pCall, $self ); 
 
            $pCall->setQuery($query); 
 
            $pCall->execute(); 
 
            my @cat_array = 
              $pCall->getSuggestedCategoryArray()->getSuggestedCategory(); 
 
            foreach my $cat_array1 (@cat_array) { 
 
                my $cat_name = $cat_array1->getCategory()->getCategoryName; 
 
                my $cat_id = $cat_array1->getCategory()->getCategoryID; 
 
                push @{ $self->{categories} }, 
                  { cat_name => $cat_name, cat_id => $cat_id }; 
 
            } 
 
#find the first category in the array, first contain the highest matching rate to the title query. 
            $self->{first_cat} = $cat_array[0]->getCategory()->getCategoryID; 
 
            return $self->{first_cat}; 
 
# return 171788; # testing category ID. note: item title must be "test listing.." 
 
        } 
 
        sub list_categories { 
 
            my $self = shift; 
 
            if ( $self->{categories} ) { 
                return $self->{categories}; 
            } 
            else { 
                return 0; 
            } 
 
        } 
 
        sub first_category { 
 
            my $self = shift; 
 
            if ( $self->{first_cat} ) { 
                return $self->{first_cat}; 
            } 
            else { 
                return 0; 
            } 
 
        } 
 
        sub delete_item { 
 
            my $self = shift; 
 
            my $get_items = {@_}; 
 
            my %convert_LC; 
 
            tie %convert_LC => 'Hash::Case::Lower' => \%$get_items; 
 
            my $item_name = \%convert_LC; 
 
            my $itemID     = $item_name->{itemid}; 
            my $end_reason = $item_name->{end_reason}; 
 
            my $pCall = eBay::API::XML::Call::EndItem->new(); 
            _account( $pCall, $self ); 
 
            $pCall->setItemID($itemID); 
            $pCall->setEndingReason($end_reason); 
 
            $pCall->execute(); 
 
            my $hasErrors = $pCall->hasErrors(); 
 
            if ($hasErrors) { 
 
                my $raErrors = $pCall->getErrors(); 
 
                foreach my $pError (@$raErrors) { 
 
                    my $sErrorCode    = $pError->getErrorCode(); 
                    my $sShortMessage = $pError->getShortMessage(); 
                    my $sLongMessage  = $pError->getLongMessage(); 
 
                    push @{ $self->{error} }, 
                      { 
                        code          => $sErrorCode, 
                        short_message => $sShortMessage, 
                        long_message  => $sLongMessage 
                      }; 
                } 
 
                $self->{get_ack} = 0; 
 
            } 
            else { 
 
                my $getACK = $pCall->getAck(); 
 
                $self->{get_ack} = 1; 
 
            } 
 
        } 
 
        sub update_item { 
 
            my $self = shift; 
 
            my $get_items = {@_}; 
 
            # Converts the all hash keys(e.g. itemID to itemid) to lower cases 
 
            my %convert_LC; 
 
            tie %convert_LC => 'Hash::Case::Lower' => \%$get_items; 
 
            my $item_name = \%convert_LC; 
 
            my $optional_fields = [ 
                'title',      'description', 
                'startprice', 'quantity', 
                'conditioncode' 
            ]; 
 
            my $method_map = { 
                title         => 'setTitle', 
                description   => 'setDescription', 
                startprice    => 'setStartPrice', 
                quantity      => 'setQuantity', 
                conditioncode => 'setConditionID', 
            }; 
 
            my $pItem = eBay::API::XML::DataType::ItemType->new(); 
 
            my $itemID = $item_name->{itemid}; 
 
            if ( defined $itemID ) { 
                $pItem->setItemID($itemID); 
            } 
            else { 
                return 0; 
            } 
 
            foreach my $field ( @{$optional_fields} ) { 
 
                if ( exists $item_name->{$field} ) { 
                    my $item_name = $item_name->{$field}; 
                    my $method    = $method_map->{$field}; 
                    $pItem->$method($item_name); 
 
                } 
            } 
 
            my $getPicture = $item_name->{pictureurl}; 
 
            my $image = eBay::API::XML::DataType::PictureDetailsType->new(); 
 
            if ( defined $getPicture ) { 
 
                $image->setPictureURL($getPicture); 
 
            } 
 
            my $thumbnail = $item_name->{setthumbnail}; 
 
            if ( defined $thumbnail ) { 
 
                $image->setGalleryURL($getPicture); 
 
            } 
 
            if ( defined $thumbnail || defined $getPicture ) { 
 
                $pItem->setPictureDetails($image); 
            } 
 
            my $pCall = eBay::API::XML::Call::ReviseItem->new(); 
 
            _account( $pCall, $self ); 
 
            $pCall->setItem($pItem); 
 
            $pCall->execute(); 
 
            my $hasErrors = $pCall->hasErrors(); 
 
            if ($hasErrors) { 
 
                my $raErrors = $pCall->getErrors(); 
 
                foreach my $pError (@$raErrors) { 
 
                    my $sErrorCode    = $pError->getErrorCode(); 
                    my $sShortMessage = $pError->getShortMessage(); 
                    my $sLongMessage  = $pError->getLongMessage(); 
 
                    push @{ $self->{error} }, 
                      { 
                        code          => $sErrorCode, 
                        short_message => $sShortMessage, 
                        long_message  => $sLongMessage 
                      }; 
                } 
 
                $self->{get_ack} = 0; 
 
            } 
            else { 
 
                my $getACK = $pCall->getAck(); 
 
                $self->{get_ack} = 1; 
 
            } 
 
        } 
 
        sub get_ack { 
 
            my $self = shift; 
            return $self->{get_ack} if exists $self->{get_ack}; 
 
        } 
 
        sub error { 
 
            my $self = shift; 
            return $self->{error} if exists $self->{error}; 
 
        } 
 
        sub add_item { 
 
            my $self = shift; 
 
            my $get_items = {@_}; 
 
            # Converts the all hash keys(e.g. itemID to itemid) to lower cases 
 
            my %convert_LC; 
 
            tie %convert_LC => 'Hash::Case::Lower' => \%$get_items; 
 
            my $item_name = \%convert_LC; 
 
            my $title                 = $item_name->{title}; 
            my $returnsAcceptedOption = $item_name->{returnsacceptedoption}; 
            my $refundOption          = $item_name->{refundoption}; 
            my $returnsWithinOption   = $item_name->{returnswithinoption}; 
            my $returnPolicyDetail    = $item_name->{returnPolicydetail}; 
            my $shippingCostPaidByOption = 
              $item_name->{shippingcostpaidbyoption}; 
            my $shippingType            = $item_name->{shippingtype}; 
            my $shippingService         = $item_name->{shippingservice}; 
            my $shippingServiceCost     = $item_name->{Shippingservicecost}; 
            my $shippingServicePriority = $item_name->{shippingservicepriority}; 
 
            my $mandatory__fields = [ 
                'title',                    'startprice', 
                'quantity',                 'description', 
                'countrycode',              'currencycode', 
                'listingduration',          'location', 
                'postalcode',               'paymentmethod', 
                'conditionid',              'dispatchtimemax', 
                'listingtype',              'payPalemailaddress', 
                'returnsacceptedoption',    'refundoption', 
                'returnswithinoption',      'returnPolicydetail', 
                'shippingcostpaidbyoption', 'shippingtype' 
            ]; 
 
            my $method_map = { 
 
                description        => 'setDescription', 
                startprice         => 'setStartPrice', 
                quantity           => 'setQuantity', 
                title              => 'setTitle', 
                countrycode        => 'setCountry', 
                currencycode       => 'setCurrency', 
                listingduration    => 'setListingDuration', 
                location           => 'setLocation', 
                postalcode         => 'setPostalCode', 
                paymentmethod      => 'setPaymentMethods', 
                conditionid        => 'setConditionID', 
                dispatchtimemax    => 'setDispatchTimeMax', 
                listingtype        => 'setListingType', 
                payPalemailaddress => 'setPayPalEmailAddress', 
 
            }; 
 
            my $pItem = eBay::API::XML::DataType::ItemType->new(); 
 
            foreach my $field ( @{$mandatory__fields} ) { 
 
                die "MISSING $field" unless defined $item_name->{$field}; 
 
                my $item_name = $item_name->{$field}; 
                my $method    = $method_map->{$field}; 
 
                if ( defined $method ) { 
 
                    $pItem->$method($item_name); 
                } 
 
            } 
 
            $pItem->getReturnPolicy() 
              ->setReturnsAcceptedOption($returnsAcceptedOption); 
            $pItem->getReturnPolicy()->setRefundOption($refundOption); 
            $pItem->getReturnPolicy() 
              ->setReturnsWithinOption($returnsWithinOption); 
            $pItem->getReturnPolicy()->setDescription($returnPolicyDetail); 
            $pItem->getReturnPolicy() 
              ->setShippingCostPaidByOption($shippingCostPaidByOption); 
            $pItem->getShippingDetails()->setShippingType($shippingType); 
 
            my $ship = 
              eBay::API::XML::DataType::ShippingServiceOptionsType->new(); 
            $ship->setShippingService($shippingService); 
            $ship->setShippingServiceCost($shippingServiceCost); 
            $ship->setShippingServicePriority($shippingServicePriority); 
            $pItem->getShippingDetails()->setShippingServiceOptions($ship); 
 
            my $categoryID = find_categories( $title, $self ); 
 
            my $pCat = eBay::API::XML::DataType::CategoryType->new(); 
 
            $pCat->setCategoryID($categoryID); 
 
            $pItem->setPrimaryCategory($pCat); 
 
            my $getPicture = $item_name->{pictureurl}; 
 
            my $image = eBay::API::XML::DataType::PictureDetailsType->new(); 
 
            if ( defined $getPicture ) { 
 
                $image->setPictureURL($getPicture); 
 
            } 
 
            my $thumbnail = $item_name->{setthumbnail}; 
 
            if ( defined $thumbnail ) { 
 
                $image->setGalleryURL($getPicture); 
 
            } 
 
            if ( defined $thumbnail || defined $getPicture ) { 
 
                $pItem->setPictureDetails($image); 
            } 
 
            my $pCall = eBay::API::XML::Call::AddItem->new(); 
 
            _account( $pCall, $self ); 
 
            $pCall->setItem($pItem); 
            $pCall->execute(); 
 
            my $hasErrors = $pCall->hasErrors(); 
 
            if ($hasErrors) { 
 
                my $raErrors = $pCall->getErrors(); 
 
                foreach my $pError (@$raErrors) { 
 
                    my $sErrorCode    = $pError->getErrorCode(); 
                    my $sShortMessage = $pError->getShortMessage(); 
                    my $sLongMessage  = $pError->getLongMessage(); 
 
                    push @{ $self->{error} }, 
                      { 
                        code          => $sErrorCode, 
                        short_message => $sShortMessage, 
                        long_message  => $sLongMessage 
                      }; 
                } 
 
                return 0; 
 
            } 
            else { 
 
                my $sItemId = $pCall->getItemID()->getValue(); 
 
                return $self->{item_id} = $sItemId; 
 
            } 
 
        } 
 
        sub get_item_id { 
            my $self = shift; 
            return $self->{item_id} if exists $self->{item_id}; 
 
        } 
 
        # Return TRUE to Perl 
        1; 
 
__END__ 
 
# eBayAPI Perl Manual 
# ------------------------------------------------------------------------------ 
=pod

 
=head1 NAME

 
eBayAPI - An Simple Interface to XML::EBAY for listing, update and delete items on eBay.

 
=head1 INHERITANCE 

 
All of the eBay API calls are inherits from the eBay::API class 

 
=head1 SYNOPSIS 

 
#1. Add eBay user credentials use  
 
	my $api = eBayAPI->new( 
	 
		apiUrl => 'API URL', 
        	devID  => 'Developer ID', 
        	appID  => 'Application ID', 
		.... 
	 
	); 
	 
	 
#2. Add item to eBay listing  
	 
	$api->add_item( 
	 
		title => 'Item Title', 
		startprice => 'Item Price', 
		quantity => 'Item Quantity',	 
		description =>'Item Descriptionm', 
		..... 
	 
	); 
	 
	 
#3. Search for a list of categories matching the title query 
 
	$api->find_categories('Title Query'); 
 
	 
	 
#4.  Updates eBay item that has currently been listed 
	 
	$api->update_item( 
	 
		itemID => "Item ID", 
		Quantity =>"Quantity No.", 
		..... 
	 
	); 
 
 
#5. Remove an item listing from eBay for various reasons 
	 
	$object->delete_item( 
	 
		itemId => "Item ID", 
		end_reason => "remove reason" 
	 
	); 
	 
 
=head1 DESCRIPTION 
 
This document describes the installation, configuration, and usage of eBayAPI.pm module. 
 
This modules contains classes from eBay::API module developed by Tim Keefer, it uses a handful of those class to develop a customise module that suits our client's need. 
 
 
 
=head1 INSTALLATION 
 
There's no installation for this module, but however there is prerequisite modules that is require to run this module. 
 
 
=head2 Prerequisite Module  

=over
 
=item * 
 
	 eBay::API - this module can be obtain from 'http://search.cpan.org/~tkeefer/eBay-API/lib/eBay/API.pm'. 
 
 
 
	* Hash::Case::Lower - module can be obtain from 'http://search.cpan.org/~markov/Hash-Case-1.02/lib/Hash/Case/Lower.pod' 
	 
 
	Note: Two of the prerequisite module require to install eBay::API has been corrupted, those are LWP::Parallel and XML - Tidy, you can get a copy of those two modules from 'https://github.com/deng2431/PX3/tree/master/corrupted_modules_ebay-api' and follow the installation instruction on those files. 
	 
 
=back
 
=head1 SUBROUTINES 
 
=head2 new() 
 
Object constructor for all api calls. 
 
Usage: 
 
	ebayAPI->new({args}) 
 
Arguments:	 
 
A hash reference containing the following possible arguments: 
	 
	apiUrl => the url to the ebay api calls, it need to either the live ebay site('https://api.ebay.com/ws/api.dll') or ebay sandbox ('https://api.sandbox.ebay.com/ws/api.dll'). 
		 
	devID = > Developer's ID, received from ebay developer's account that is linked to your ebay account. 
		 
	appID = > Application ID, received from ebay developer's account that is linked to your ebay account. 
		 
	certID = > certificate ID, received from ebay developer's account that is linked to your ebay account. 
		 
	authToken => authentication Token, a token that acts as a password to the linked ebay account, it can be received after the developer and ebay account is linked. 
		 
	siteID = > Site ID, the ebay country site that you want to use for the api calls. the site ID uses codes for recongnising is in numbers. e.g 0 = US site(.com) and 15 = AUS site(.com.au). 
		 
	complvl => compatibility level, the level of compatibility you want to test the api calls on, bear in mind not all api calls support the new compatibility and vice-versa. 
		 
		 
 
 
=head2 add_item() 
 
Add a item to eBay listing. 
 
	 
Usage: 
 
	$api->add_item({args}); 
	 
Arguments: 
	 
	title => Name of the item as it appears in the listing or search results. Required for most items. 
		 
	quantity => Number of items in the listing 
		 
	description => Description of the item 
		 
	startprice => The original price of the item at listing. 
		 
	countrycode => Which country the item will be listed on. See link a list of country code: URL :  http://developer.ebay.com/devzone/xml/docs/reference/ebay/types/countrycodetype.html 
		 
	currencycode => The preferred currency for payment. See link a list of currency code: URL : http://developer.ebay.com/devzone/shopping/docs/callref/types/currencycodetype.html 
		 
	listingduration => The amount of time the item will be listed on eBay. See link for available days. URL: http://developer.ebay.com/devzone/xml/docs/reference/ebay/types/ListingDurationCodeType.html 
		 
	location => The location of the item. 
		 
	postalcode => post of the location which the item is located 
		 
	paymentmethod => Specific whicch payment method will be accepted. for a list of payment methods see url. URL: http://developer.ebay.com/devzone/xml/docs/reference/ebay/types/BuyerPaymentMethodCodeType.html 
		 
	conditioncode => update the item condition, only input condition ID is exceptable. An list of ID is available at 'http://developer.ebay.com/Devzone/finding/CallRef/Enums/conditionIdList.html' 
		 
	dispatchtimemax => The amount of time it will take for the item to be dispatched. 
		 
	listingtype => The type of listing the item will be under, Buy it now or Auction. For a full list see url. URL: http://developer.ebay.com/devzone/xml/docs/reference/ebay/types/ListingTypeCodeType.html 
		 
	payPalemailaddress => THe paypal email that will be receiving the payments from the buyers, the paypal email musted be linked with the seller's eBay account. 
		 
	returnsacceptedoption => Specific whether return is acceptable for the listing item. 
		 
	refundoption => Specific how will the refund be made if a item were to be returned. 
		 
	returnswithinoption => The amount of time an item can be return to the seller. 
		 
	returnpolicydetail => An description of what the return policy are. 
		 
	shippingcostpaidbyoption => Specific who will paid for the return cost of the item. 
		 
	shippingtype => The shipping cost model offered by the seller. For a full list of option see url. URL: http://developer.ebay.com/devzone/xml/docs/reference/ebay/types/shippingtypecodetype.html 
		 
	shippingservice => A shipping service used to ship an item. For a dfull list see url. URL: http://developer.ebay.com/devzone/xml/docs/reference/ebay/types/ShippingServiceCodeType.html 
		 
	Shippingservicecost => Specific the cose of the shipping service. 
		 
	shippingservicepriority => Specific whether this item will be shipped using priority service. code: 1 = Priority, 0 = non-Priority 
		 
	pictureurl => Set a item's picture using a external link 
		 
	setthumbnail => set the item's thumbnail using a external link 
		 
 
Return: 
 
	Item's ID upon success. 
		 
=head2 update_item() 
 
Update an item from ebay listing that is currently active. An fee might occur for updating an item. 
 
	 
Usage: 
 
	$api->update_item({args}); 
	 
Arguments: 
 
	itemID => Item's ID for updating 
	 
	title => alter the item's title 
	 
	quantity => update the available quantity for the item 
	 
	description => alter the description of the item 
	 
	startprice => change the item's price 
	 
	pictureurl => update the item's picture using external link. 
	 
	setthumbnail => change the item's thumbnail 
	 
	conditioncode => update the item condition, only input condition ID is exceptable. An list of ID is available at 'http://developer.ebay.com/Devzone/finding/CallRef/Enums/conditionIdList.html' 
 
 
 
 
		 
 
=head2 find_categories() 
 
Search eBay category system and return the best matching categories for the keyword/query.  
 
Usage: 
 
	$api->find_categories("query") 
 
Return: 
 
Once the call has been excuted it will return two properties upon successfuly result. 
 
$api->list_categories 
		 
	Return a hash of categories. Return 0 upon failure. 
		Hash Keys: 
			cat_id => Category ID  
			cat_name => Category Name 
			 
		Example: 
			foreach my $cat (@{$api->list_categories}){ 
					 
			$cat->{cat_id}; 
			$cat->{cat_name}; 
					 
			} 
 
$api->first_category 
	 
		Return the first category ID which contain the most suitable category for listing with the entered keyword/query. Return 0 upon failure. 
		 
	 
 
 
=head2 delete_item() 
 
Remove an item from ebay listing that is currently active. 
 
	 
Usage: 
 
	$api->delete_item({args}); 
	 
Arguments: 
 
	itemID => Item's ID requesting for removal 
	end_reason => "End Reason Code" 
	 
	Note: A list of end reason code is available at 'http://search.cpan.org/~tkeefer/eBay-API/lib/eBay/API/XML/DataType/Enum/EndReasonCodeType.pm'. 
	 
	 
 
 
	 
 
=head2 Common response (output) properties 
 
$api -> get_ack() 
 
	Return 1 for successful call and 0 for failure. 
	 
 
=head2 Common error properties 
 
$api->error() 
 
	Return a hash reference of error code receive for failed calls. 
		Hash Keys:  
			code - error code 
			short_message - brief message of the error 
			long_message - details message of the error 
			 
		Example: 
			 foreach my $error (@{$api->error()}) { 
			  
				$error->{code}: 
				$error->{short_message} 
				$error->{long_message} 
			  
			 } 
 
 
 
	 
		 
		

