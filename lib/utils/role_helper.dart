String getRoleName(String cycd) {
  switch (cycd) {
    case '0': return '参与者';
    case '1': return '组织者';
    case '4': return '观众';
    default: return '未知身份($cycd)';
  }
}