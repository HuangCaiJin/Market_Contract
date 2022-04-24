// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./ECDSA.sol";
import "./Expend.sol";
import "./ReentrancyGuard.sol";
contract Market is Expend,ReentrancyGuard {
    
    string public constant name = "Market";
    
    
    // 可访问的,代理合约地址
    // mapping(address => bool) public model;
    // 质押存储钱包地址
    /* address pledgeWallte = 0xAFCe2aE13Af7e6A8f651B32dD930DC9c58682796;
    struct pledgeDetail {
      address coin;
      uint amount;
      uint end;
    }
    mapping(address => mapping(uint => pledgeDetail)) signPledge; */
    // 过期的签名列表
    // mapping(bytes => bool) public forbidSignature;
    
    
    
    event Trade(address _buyer,address _seller,address _gooder,address _artToken,uint _tokenID,address _tradeToken,uint _price,uint _time,uint _trade,uint _sellPrice,uint _amount);
    event Cancel(address _offer,address _artToken,uint _tokenID,address _tradeToken,uint _price,uint _time,uint _type,uint _amount);
    event Winning(address _bider,address _coin,address _to,uint _price,uint _tokenID,address _nft,uint _amount);
    

    constructor (
      address _owner,
      address _admin,
      uint _fee,
      address _wallet,
      address _register,address _verification) 
      Expend(
        _owner,
        _admin,
        _fee,
        _wallet,
        _register,_verification){}

    
    function AuctionTransferFrom(
      address[] memory _adders,
      uint[] memory _ints,
      bytes memory _signature) public  {
        require(msg.sender == owner || msg.sender == admin,"forbid 403");
        // _adders[0] 出价者
        // _adders[1] 币种
        // _adders[2] 收款地址
        // _adders[3] 平台NFT地址
        // _ints[0]   价格
        // _ints[1]   tokenID
        // _ints[2]   出价时间
        // _ints[3]   发行量
        // _signature 出价者签名
        require(!curRegistry.forbidSignature(_signature),"Invalid");
        require(isPlatform[_adders[3]],'Illegal nft');
        address signer = ECDSA.recover(getEthSignedMessageHash(keccak256(abi.encodePacked(_adders[1],_adders[3],_ints[0],_ints[1],_ints[2],_ints[3]))), _signature);
        require(_adders[0] == signer,"ERR 403");
        IERC20 erc20Coin = IERC20(_adders[1]);
        require(erc20Coin.transferFrom(signer,_adders[2],_ints[0]), "fail");
        if(platformType[_adders[3]] == 1155){
            IERC1155 nft1155CoinEnd = IERC1155(_adders[3]);
            if(!nft1155CoinEnd.exist(_ints[1])){
              nft1155CoinEnd.mint(msg.sender,_adders[0],_ints[1],_ints[3],bytes("0x0"));
            }else{
              nft1155CoinEnd.safeTransferFrom(msg.sender,_adders[0],_ints[1],_ints[3],bytes("0x0"));
            }
            require(nft1155CoinEnd.balanceOf(_adders[0],_ints[1]) >= _ints[3],"ERC1155 auction fail !");
        }else if(platformType[_adders[3]] == 721){
            IERC721 nft721CoinEnd = IERC721(_adders[3]);
            if(!nft721CoinEnd.exist(_ints[1])){
              nft721CoinEnd.mint(msg.sender,_adders[0],_ints[1],bytes("0x0"));
            }else{
              nft721CoinEnd.transferFrom(msg.sender,_adders[0],_ints[1]);
            }
            require(nft721CoinEnd.ownerOf(_ints[1]) == _adders[0],"fail!");
        }else{
          revert('not suport !');
        }
        
        curRegistry.forbid(_signature);
        emit Winning(_adders[0],_adders[1],_adders[2],_ints[0],_ints[1],_adders[3],_ints[3]);
    }
    
    // 消息哈希  1:出价签名 2:售卖签名
    function getMsgHash(Order memory o,uint _who,address seller) internal view returns (bytes32 msghash){
      (address createor,uint nonce,,) = curRegistry.getTrade(o.art,o.id,seller,o.sale);
      if(createor == address(0)){
        createor = seller;
      }
      if(_who == 1){
        msghash = keccak256(abi.encodePacked(
        o.doer,
        o.art,
        o.token,
        o.gooder,
        o.id,
        o.price,
        o.sale,
        o.trade,
        o.end,
        o.volume,
        o.supply,
        createor,
        nonce));
      }else if(_who == 2){
        msghash = keccak256(abi.encodePacked(
        o.doer,
        o.art,
        o.token,
        o.id,
        o.price,
        o.sale,
        o.trade,
        o.end,
        o.amount,
        o.supply,
        createor,
        nonce));
      }else{
        revert('none !');
      }
    }
    // 取消签名
    function cancelOffer(
      address[] memory ads,
      uint[] memory us,
      bytes memory signs,
      uint _who) public nonReentrant {
      Order memory o = Order(ads[0],ads[1],ads[2],ads[3],us[0],us[1],us[2],us[3],us[4],us[5],us[6],us[7],us[8],us[9],bytes("0x0a"));
      
      bytes32 messageHash = getMsgHash(o,_who,ads[4]);
      address signer = ECDSA.recover(getEthSignedMessageHash(messageHash), signs);
      require(signer == msg.sender,"ERROR 403");
      curRegistry.forbid(signs);
      if(_who == 1){
        emit Cancel(o.doer,o.art,o.id,o.token,o.price,block.timestamp,_who,us[9]);
      }else if(_who == 2){
        emit Cancel(o.doer,o.art,o.id,o.token,o.price,block.timestamp,_who,us[7]);
      }else{
        revert('Is not support !');
      }
      
    }
    /* 
    立即购买：
        参数一：[卖家地址,卖家签名的NFT合约,卖家签名的交易的代币或ETH,推荐者地址]
        参数二：[
          卖家签名的NFTID,
          卖家签名的价格,
          卖家签名的出售时间,
          创建者签名的NFT创建时间,
          卖家签名的交易类型,
          NFT类型,
          卖家签名的售卖结束时间,
          版税比率,
          版税有效期时间戳
         
        ]
        参数三：卖家设置价格的签名列表，第一个为最新的价格也是最低的 bytes[]
        参数四：创建者创建NFT的签名 bytes

        卖家签名内容：卖家地址,NFT合约,交易的代币或ETH,NFTID,价格,出售时间,交易类型,NFT类型,结束时间
        创建者签名内容：NFTID,创建时间


    竞拍出价:
        参数一: [出价者地址,NFT合约,交易的代币或ETH,出价者签名推荐地址]
        参数二: [
          NFTID,
          卖家签名的低价,
          卖家签名的出售时间,
          创建者签名的NFT创建时间,
          卖家签名的交易类型,
          NFT类型,
          卖家签名的售卖结束时间,
          出价者签名的报价,
          出价者签名的报价时间,
          出价者签名的报价结束时间,
          版税比率,
          版税有效期时间戳
        ]
        参数三: 卖家设置低价的签名列表，第一个为最新的价格也是最低的 bytes[]
        参数四: 版税签名 bytes
        参数五: 出价签名列表，第一个为卖家选择的出价的签名 bytes[]

        卖家签名内容：卖家地址,NFT合约,交易的代币或ETH,NFTID,低价,出售时间,交易类型,NFT类型,结束时间
        出价者签名内容：出价地址,NFT合约,交易的代币或ETH,,NFTID,报价,报价时间,交易类型,NFT类型,报价结束时间,推荐地址
        创建者签名内容：NFTID,创建时间
        struct Order {
          address doer;      //参数一[0]
          address art;       //参数一[1]
          address token;     //参数一[2]  如果是使用ETH交易地址为0x0
          address gooder;    //参数一[3]
          uint id;           //参数二[0]
          uint price;        //参数二[1]
          uint sale;         //参数二[2]
          uint create;       //参数二[3]
          uint trade;        //参数二[4]  Buy:1 Sell:2
          uint nft;          //参数二[5]  erc721:721 erc1155:1155
          uint end;          //参数二[6]
          bytes tradeSign; //参数四
        }
     */
    function checkRoyalties(Order memory o,address seller,uint edition,uint validity) internal view returns (bool _pass){
      uint time = block.timestamp;
      require(validity >= time,'Signature expired');
      address certifier = ECDSA.recover(getEthSignedMessageHash(keccak256(abi.encodePacked(
        msg.sender,
        o.art,
        seller,
        o.id,
        edition,
        validity,
        o.amount,
        o.volume))),
        o.tradeSign);
        require(verification == certifier,'Illegal royalties');

      _pass = verification == certifier;
    }
 
    function setVolume(Order memory o,address _seller) internal {
        uint tradeAmount;
        uint tradeNonce;
        (,tradeNonce,tradeAmount,) = curRegistry.getTrade(o.art,o.id,_seller,o.sale);
        if(tradeAmount + o.volume == o.amount){
            curRegistry.setTradeAmount(_seller,o.sale,tradeAmount + o.volume);
            curRegistry.setTradeNonce(o.art,o.id,_seller,tradeNonce + 1);
        }else if(tradeAmount + o.volume < o.amount){
            curRegistry.setTradeAmount(_seller,o.sale,tradeAmount + o.volume);
        }else{
            revert("Purchase quantity out of range");
        }
        curRegistry.setTradeStatus(o.art,o.id,true);
    }
    function trade(
        address[] memory ads,
        uint[] memory us,
        bytes memory ss,
        bytes memory cs,
        bytes memory bs
    ) public payable nonReentrant{
      require(msg.sender == owner || (!curRegistry.isRevoked() && curRegistry.userPass(msg.sender)));
      require(us[5] == 721 || us[5] == 1155, "Illegal nft type !");
      address newCreateor;
      bool tradeStatus;
      if(us[4] == 1){
        // 立即购买
        Order memory o = Order(ads[0],ads[1],ads[2],ads[3],us[0],us[1],us[2],us[3],us[4],us[5],us[6],us[9],us[10],us[11],cs);
        // 检查版费
        require(checkRoyalties(o,o.doer,us[7],us[8]),'Royalties check fail');
        // 签名检查
        _checkPass(o,ss,2,o.doer);
        (,,,tradeStatus) = curRegistry.getTrade(o.art,o.id,o.doer,o.sale);
        _nBalance(o.nft,o.art,o.id,o.doer,tradeStatus);
        (newCreateor,,,) = curRegistry.getTrade(o.art,o.id,o.doer,o.sale);
        _erc20Transfer(msg.sender,o,o.price*o.volume,newCreateor,o.doer,us[7],tradeStatus);
        _nTransfer(msg.sender,o,newCreateor,o.doer,tradeStatus);

        setVolume(o,o.doer);
        emit Trade(msg.sender,o.doer,o.gooder,o.art,o.id,o.token,o.price,block.timestamp,1,o.price,o.volume);
      }else if (us[4] == 2 || us[4] == 3){
        // 出价竞拍
        Order memory b = Order(ads[0],ads[1],ads[2],ads[3],us[0],us[7],us[8],us[3],us[4],us[5],us[9],us[12],us[13],us[14],cs);
        Order memory o;
        if(b.trade == 2){
          o = Order(msg.sender,ads[1],ads[2],ads[3],us[0],us[1],us[2],us[3],us[4],us[5],us[6],us[12],us[13],us[14],cs);
          require(o.token != address(0),"We won't support current token");
          require(us[7] > us[1],"price lower");
        }else if(b.trade == 3){
          o = Order(msg.sender,ads[1],ads[4],ads[3],us[0],us[1],us[2],us[3],1,us[5],us[6],us[12],us[13],us[14],cs);
          require(b.token != address(0),"We won't support current token");
        }
        // 检查版费
        require(checkRoyalties(o,msg.sender,us[10],us[11]),'Royalties check fail');
        // 签名检查
        _checkPass(o,ss,2,msg.sender);
        _checkPass(b,bs,1,msg.sender);
        curRegistry.forbid(bs);

        (,,,tradeStatus) = curRegistry.getTrade(o.art,o.id,msg.sender,o.sale);
        _nBalance(o.nft,o.art,o.id,msg.sender,tradeStatus);
        (newCreateor,,,) = curRegistry.getTrade(o.art,o.id,msg.sender,o.sale);
        // erc20或eth转账
        if(b.trade == 2){
          _erc20Transfer(b.doer,o,b.price*b.volume,newCreateor,msg.sender,us[10],tradeStatus);
        }else if(b.trade == 3){
          _erc20Transfer(b.doer,b,b.price*b.volume,newCreateor,msg.sender,us[10],tradeStatus);
        }
        // nft转账
        _nTransfer(b.doer,o,newCreateor,msg.sender,tradeStatus);
        // 记录交易后的所属关系

        setVolume(o,msg.sender);

        emit Trade(b.doer,msg.sender,o.gooder,o.art,o.id,o.token,b.price,block.timestamp,b.trade,o.price,o.volume);
      }else{
        revert("not have trade type !");
      }
      
    }

    function _checkPass(
      Order memory order,
      bytes memory signs,
      uint _who,address seller) 
      internal view {
      require(!curRegistry.forbidSignature(signs),"Invalid");
      require(order.amount > 0 && order.supply >= order.amount && order.amount >= order.volume,"Illegal numbel");
      require(order.end/1000 >= block.timestamp && Address.isContract(order.art) && order.sale/1000 < block.timestamp, "Illegal parameter !");
      if(order.token != address(0)){
        require(Address.isContract(order.token),"Is not token !");
      }
      bytes32 messageHash = getMsgHash(order,_who,seller);
      address signer = ECDSA.recover(getEthSignedMessageHash(messageHash), signs);

      
      // 判断签名
      require(signer == order.doer,"Illegal signature !");
    }
}
