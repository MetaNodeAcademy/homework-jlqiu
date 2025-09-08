// SPDX-License-Identifier: MIT
pragma solidity ^0.8;


contract Voting {

     struct RomanDigit {
        string key;
        uint value;
    }

    RomanDigit[7] private romanDigits;
    mapping(address => uint) public votesReceived;
    uint public votesCount;

    constructor() payable {

        romanDigits[0] = RomanDigit({key:"I", value:1});
        romanDigits[1] = RomanDigit({key:"V", value:5});
        romanDigits[2] = RomanDigit({key:"X", value:10});
        romanDigits[3] = RomanDigit({key:"L", value:50});
        romanDigits[4] = RomanDigit({key:"C", value:100});
        romanDigits[5] = RomanDigit({key:"D", value:500});
        romanDigits[6] = RomanDigit({key:"M", value:1000});
      
    }
    // 投票函数 ok
    function vote(address addr) external  {

        uint num = votesReceived[addr];
         votesReceived[addr] = num + 1;
        
    }

    
    // 获取候选人投票数 ok
    function getVotes(address adr) external view returns(uint) {
        return votesReceived[adr];
    }

   // 重置所有候选人的得票数  nook
    function resetVotes() external  {
       votesCount ++;
    }

    function getIntValue(bytes1 romanStr) private pure returns(int) {
        if (romanStr == bytes1('I'))return 1;
        if (romanStr == bytes1('V'))return 5;
        if (romanStr == bytes1('X'))return 10;
        if (romanStr == bytes1('L'))return 50;
        if (romanStr == bytes1('C'))return 100;
        if (romanStr == bytes1('D'))return 500;
        if (romanStr == bytes1('M'))return 1000;
        return 0;
     }

 // solidity 基础作业2  反转字符串  ok
    function reverseStr(string memory str) external pure returns(string memory) {
        bytes memory b = bytes(str);
        bytes memory reversed = new bytes(b.length);
        for (uint i = 0; i < b.length; i++) {
            // reversed = reversed + b[i] ;
            reversed[b.length -1 -i] = b[i];
        }
        return string(reversed);
        
    }

    // solidity 基础作业3 实现整数转罗马数字  nook

    function intToRoman(uint num) public view returns(string memory) {
        string memory result; // 计算后的罗马数字
        for(uint256 i=0; i<romanDigits.length; i++) {
            if(num >= romanDigits[i].value) {
                result = string(abi.encodePacked(result, romanDigits[i].key));
                num -= romanDigits[i].value;
            }
        }
       return result;

    }

     // solidity 基础作业4 实现罗马数字转整数  nook
     function romanToInt(string memory str) public pure returns(int) {
         bytes memory romanI = bytes(str);
         
        int result = 0;
        int preValue = 0;
        for(uint i = romanI.length; i > romanI.length; i++) {
            // 获取罗马数字对应的整数，然后再相加
            int value  = getIntValue(romanI[i]);
            
            if(value < preValue) {
                result = result - value;

            } else if (value > preValue) {
                result = result + value;
            }
            preValue = value;

        }

        return result;


     }
     // 合并两个有序数组  ok

     function mergeTwoSortedArray(uint[] memory array1, uint[] memory array2) public pure returns(uint[] memory) {
        uint length1 = array1.length;
        uint length2 = array2.length;
        uint[] memory result = new uint[](length1 + length2);
        uint i = 0;
        uint j = 0;

        uint k = 0;

        while(i < length1 && j < length2) {
            if(array1[i] <= array2[j]) {
             result[k] = array1[i];
                i++;  
            } else {
                result[k] = array2[j];
                j++;
            }
            k++;
        }

        while(i < length1) {
            result[k] = array1[i];
            i++;
            k++;

        }

        while(j < length2) {
            result[k] = array2[j];
            j++;
            k++;
        }

        return result;
     }

     // 二分查找  ok

       function searchResult(uint[] memory arr, uint searchValue) public pure returns(uint) {
        uint left = 0;
        uint right = arr.length -1;
        
        while(left <= right) {
            uint mid = (left + right) / 2;
            if(arr[mid] == searchValue) {
                return mid;
            } else if(arr[mid] < searchValue) {
                left = mid + 1;
            } else {
                right = mid - 1;
            }
        }
        return 9999;
       }
    
}