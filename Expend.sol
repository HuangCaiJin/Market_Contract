// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
import './IERC20.sol';
import './IERC721.sol';
import './IERC1155.sol';
import "./Address.sol";
import './InitOwner.sol';
interface Register {
    function userPass(address _user) external view returns (bool);
    function isRevoked() external view returns (bool);
    function isOpen(address _coin) external view returns (bool);
    function forbidSignature(bytes memory _s) external view returns (bool);
    function forbid(bytes memory _s) external;

    function setTradeCreater(address _nft,uint _tokenId,address _creator) external;
    function setTradeNonce(address _nft,uint _tokenId,address _seller,uint _nonce) external;
    function setTradeAmount(address _seller,uint _index,uint _amount) external;
    function setTradeStatus(address _nft,uint _tokenId,bool _status) external;

    function getTrade(address _nft,uint _tokenId,address _seller,uint _index) external view returns(address _c,uint _n,uint _a,bool _s);

}

contract Expend is InitOwner {
    uint internal decimals = 10 ** 18;

    // 交易平台收取的手续费
    uint public fee;


    mapping(address => uint) public platformType;
    mapping(address => bool) public isPlatform;

    // Kabukicoin钱包地址
    address internal KabukicoinWallte;
    address internal admin;
    address internal verification;
    
    Register curRegistry;
    
    struct Order {
      address doer;//钱包地址
      address art;//NFT合约地址
      address token;//购买使用的ERC20代币地址，如果是使用ETH交易地址为0x0
      address gooder;//推荐者地址
      uint id;//NFT的tokenID
      uint price;//买家设置的NFT出售价格
      uint sale;//买家设置出售价格的时间戳
      uint create;//创建者创建的时间戳
      uint trade; //Buy:1 Sell:2
      uint nft; //erc721:721 erc1155:1155
      uint end;
      uint amount;
      uint supply;
      uint volume;
      bytes tradeSign; // 版税签名
    }


    event Config(address _wallet,address _admin,address _register,address _verification,uint _fee);
    event Award(address _coin,uint _amount,address _creator,uint rate,uint price,uint tokenID,address _nft,uint _count);
    event OpenPlatformNFT(address[] _nfts, uint[] _type, bool[] _onoff);
    
    constructor (address _owner,address _admin,uint _fee,address _wallet,address _newRegister,address _verification)
    {   
        initOwner(_owner);
        marketConfig(_wallet,_admin,_newRegister,_verification,_fee);
    }
    function OpenPlatform(
      address[] memory _nft,
      uint[] memory _type,
      bool[] memory _onoff
    ) public onlyOwner{
      for(uint i = 0; i < _nft.length; i++){
        platformType[_nft[i]] = _type[i];
        isPlatform[_nft[i]] = _onoff[i];
      }
      emit OpenPlatformNFT(_nft,_type,_onoff);
    }
    function marketConfig(
      address _wallet,
      address _admin,
      address _newRegister,
      address _verification,
      uint _fee) public onlyOwner{
      KabukicoinWallte = _wallet;
      admin = _admin;
      fee = _fee;
      curRegistry = Register(_newRegister);
      verification = _verification;
      emit Config(_wallet,_admin,_newRegister,_verification,_fee);
    }

    // 以太坊对消息Hash进行签名
    function getEthSignedMessageHash(bytes32 messageHash) internal pure returns (bytes32)
    {
        return
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    messageHash
                )
            );
    }

    // nft类型(1155 OR 721) nft地址 nftid nft售卖者的地址 交易次数
    function _nBalance(uint t,address a,uint i,address d,bool status) internal {
      // 判断NFT
      if(t == 721){
        IERC721 nft721Coin = IERC721(a);
        // 如果当前NFT不属于sender
        if(nft721Coin.ownerOf(i) != d){
          // 如果NFT为平台NFT,并且tokenID不存在
          if(isPlatform[a] && !nft721Coin.exist(i)){
            curRegistry.setTradeCreater(a,i,d);
            
          }else{
            revert("Not belong you !");
          }
        }else{
          // 如果之前没有交易过当前买家就是创建者
          if(!status){
              curRegistry.setTradeCreater(a,i,d);

          }
        }
      }
      if(t == 1155){
        IERC1155 nft1155Coin = IERC1155(a);
        // 如果卖家钱包，当前NFT余额为0
        if(nft1155Coin.balanceOf(d,i) < 1){
          // 如果NFT为平台NFT,并且tokenID不存在
          if(isPlatform[a] && !nft1155Coin.exist(i)){
            curRegistry.setTradeCreater(a,i,d);

          }else{
            revert("nft Insufficient!");
          }
        }else{
          // 如果之前没有交易过当前买家就是创建者
          if(!status){
              curRegistry.setTradeCreater(a,i,d);

          }
        }
      }
    }
   
    // 买家地址 nft类型(1155 OR 721) nft地址 创建者地址 所有者地址 nftid 交易次数
    function _nTransfer(address r,Order memory ord,address c,address b,bool status) internal {
      if(ord.nft == 1155){
        IERC1155 nft1155CoinEnd = IERC1155(ord.art);
        if(!status){
          if(nft1155CoinEnd.balanceOf(c,ord.id) < 1){
            if(isPlatform[ord.art] && !nft1155CoinEnd.exist(ord.id)){
              // nft1155CoinEnd.mint(c,r,ord.id,ord.supply,bytes("0x0"));
              nft1155CoinEnd.mint(c,c,ord.id,ord.supply,bytes("0x0"));
              nft1155CoinEnd.safeTransferFrom(c,r,ord.id,ord.volume,bytes("0x0"));
            }else{
              revert("nft Insufficient!");
            }
          }else{
            nft1155CoinEnd.safeTransferFrom(c,r,ord.id,ord.volume,bytes("0x0"));
          }
        }else{
          nft1155CoinEnd.safeTransferFrom(b,r,ord.id,ord.volume,bytes("0x0"));
        }
        
        require(nft1155CoinEnd.balanceOf(r,ord.id) > 0,"NFT transfer fail !");

      }
      if(ord.nft == 721){
        IERC721 nft721CoinEnd = IERC721(ord.art);
        if(!status){
          if(nft721CoinEnd.ownerOf(ord.id) != c){
            if(isPlatform[ord.art] && !nft721CoinEnd.exist(ord.id)){
              nft721CoinEnd.mint(c,r,ord.id,bytes("0x0"));
            }else{
              revert("Not belong you !");
            }
          }else{
            nft721CoinEnd.transferFrom(c,r,ord.id);
          }
        }else{
          nft721CoinEnd.transferFrom(b,r,ord.id);
        }
        require(nft721CoinEnd.ownerOf(ord.id) == r,"NFT transfer fail !");
      }
    }
    
    // 买家地址 erc20代币地址 价格 推荐地址 创建者 所属者 交易次数 nft合约地址 版税签名时间戳
      function _erc20Transfer(
        address o,
        Order memory or,
        uint p,
        address c,
        address b,
        uint v,bool status) 
      internal {
      uint gainCount;
      if(or.token != address(0)){
        // 是否开通交易的ERC20代币
        require(curRegistry.isOpen(or.token), "ERC20 Not opened");
        IERC20 erc20Coin = IERC20(or.token);
        if(v > 0 && isPlatform[or.art]){
            emit Award(or.token,v*p/decimals,c,v,p,or.id,or.art,or.volume);
        }
        if(fee > 0){
            require(erc20Coin.transferFrom(o,KabukicoinWallte,(fee+v)*p/decimals), "Fee send fail");
        }
        // 剩余的全部发送给卖家
        gainCount = decimals - fee - v;
        if(!status){
            require(erc20Coin.transferFrom(o,c,gainCount*p/decimals), "Seller receive fail");
        }else{
            require(erc20Coin.transferFrom(o,b,gainCount*p/decimals), "Seller receive fail");
        }
        
      }else{
        if(v > 0 && isPlatform[or.art]){
            emit Award(or.token,v*p/decimals,c,v,p,or.id,or.art,or.volume);
        }
        if(fee > 0){
          Address.sendValue(payable(KabukicoinWallte),(fee+v)*p/decimals);
        }
        gainCount = decimals - fee - v;
        if(!status){
          Address.sendValue(payable(c),gainCount*p/decimals);
        }else{
          Address.sendValue(payable(b),gainCount*p/decimals);
        }
      }
    }
}