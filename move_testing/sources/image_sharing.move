module my_addrx::image_sharing {
    use std::string::String;
    use std::signer;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_std::table::{Self, Table};
    use std::vector;

    struct ImageInfo has store {
        owner: address,
        ipfs_hash: String,
        description: String,
        likes: u64,
        tips_received: u64,
    }

    struct UserProfile has key {
        uploaded_images: Table<u64, ImageInfo>,
        image_count: u64,
    }

    struct PlatformData has key {
        all_images: Table<u64, ImageInfo>,
        image_count: u64,
    }

    const E_NOT_INITIALIZED: u64 = 1;
    const E_ALREADY_INITIALIZED: u64 = 2;
    const E_NOT_OWNER: u64 = 3;
    const E_IMAGE_NOT_FOUND: u64 = 4;

    
fun init_module(account: &signer) {
    let account_addr = signer::address_of(account);
    // Check if PlatformData exists globally, not by account address
    assert!(!exists<PlatformData>(@my_addrx), E_ALREADY_INITIALIZED); 
    
    move_to(account, PlatformData {
        all_images: table::new(),
        image_count: 0,
    });
}


    public entry fun initialize_profile(account: &signer) {
        let account_addr = signer::address_of(account);
        assert!(!exists<UserProfile>(account_addr), E_ALREADY_INITIALIZED);
        
        move_to(account, UserProfile {
            uploaded_images: table::new(),
            image_count: 0,
        });
    }
   #[view]
public fun is_profile_initialized(account_addr: address): bool {
    exists<UserProfile>(account_addr)
}



    public entry fun upload_image(account: &signer, ipfs_hash: String, description: String) acquires UserProfile, PlatformData {
        let account_addr = signer::address_of(account);
        assert!(exists<UserProfile>(account_addr), E_NOT_INITIALIZED);
        
        let user_profile = borrow_global_mut<UserProfile>(account_addr);
        let platform_data = borrow_global_mut<PlatformData>(@my_addrx);
        
        let image_info = ImageInfo {
            owner: account_addr,
            ipfs_hash,
            description,
            likes: 0,
            tips_received: 0,
        };
        
        // Add to user profile
        table::add(&mut user_profile.uploaded_images, user_profile.image_count, image_info);

        // Add a new instance to platform data
        table::add(&mut platform_data.all_images, platform_data.image_count, ImageInfo {
            owner: account_addr,
            ipfs_hash: ipfs_hash,
            description: description,
            likes: 0,
            tips_received: 0,
        });
        
        user_profile.image_count = user_profile.image_count + 1;
        platform_data.image_count = platform_data.image_count + 1;
    }

    public entry fun like_image(_account: &signer, image_id: u64) acquires PlatformData {
        let platform_data = borrow_global_mut<PlatformData>(@my_addrx);
        assert!(table::contains(&platform_data.all_images, image_id), E_IMAGE_NOT_FOUND);
        
        let image_info = table::borrow_mut(&mut platform_data.all_images, image_id);
        image_info.likes = image_info.likes + 1;
    }

    public entry fun tip_image(account: &signer, image_id: u64, amount: u64) acquires PlatformData {
        let _account_addr = signer::address_of(account);
        let platform_data = borrow_global_mut<PlatformData>(@my_addrx);
        assert!(table::contains(&platform_data.all_images, image_id), E_IMAGE_NOT_FOUND);
        
        let image_info = table::borrow_mut(&mut platform_data.all_images, image_id);
        let owner = image_info.owner;
        
        coin::transfer<AptosCoin>(account, owner, amount);
        image_info.tips_received = image_info.tips_received + amount;
    }

    #[view]
    public fun get_image_info(image_id: u64): (address, String, String, u64, u64) acquires PlatformData {
        let platform_data = borrow_global<PlatformData>(@my_addrx);
        assert!(table::contains(&platform_data.all_images, image_id), E_IMAGE_NOT_FOUND);
        
        let image_info = table::borrow(&platform_data.all_images, image_id);
        (image_info.owner, *&image_info.ipfs_hash, *&image_info.description, image_info.likes, image_info.tips_received)
    }

    #[view]
    public fun get_all_image_ids(): vector<u64> acquires PlatformData {
        let platform_data = borrow_global<PlatformData>(@my_addrx);
        let image_count = platform_data.image_count;
        let ids = vector::empty();
        let i = 0;
        while (i < image_count) {
            if (table::contains(&platform_data.all_images, i)) {
                vector::push_back(&mut ids, i);
            };
            i = i + 1;
        };
        ids
    }
   // This function retrieves the total tips received by an account.
// This function retrieves the total tips received by an account.
public fun get_total_tips_received(account: address): u64 acquires PlatformData {
    let platform_data = borrow_global<PlatformData>(@my_addrx);
    let total_tips: u64 = 0;

    let image_count = table::length(&platform_data.all_images);
    let i = 0;
    while (i < image_count) {
        if (table::contains(&platform_data.all_images, i)) {
            let image_info = table::borrow(&platform_data.all_images, i);
            total_tips = total_tips + image_info.tips_received;
        };
        i = i + 1;
    };

    total_tips
}


public entry fun get_images_uploaded_by_user(account: address): vector<ImageInfo> acquires PlatformData {
    let platform_data = borrow_global<PlatformData>(@my_addrx);
    let uploaded_images: vector<ImageInfo> = vector::empty<ImageInfo>();

    // Iterate through all images and collect those uploaded by the specified user
    for (image_id, image_info) in table::iter(&platform_data.all_images) {
        if (image_info.owner == account) {
            vector::push_back(&mut uploaded_images, image_info);
        }
    }
    
    return uploaded_images; // Return the vector of uploaded images
}

}
