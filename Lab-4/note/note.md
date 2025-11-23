### 1.握手信号是一种确保数据可靠传输的协议，包含两个关键信号：

- **ready**：接收方准备好的信号

- **valid**：发送方数据有效的信号

  > [!NOTE]
  >
  > 两者都准备好后执行。

### 2.请求-执行分离规范化规则

第一部分记录请求，修改对应条件使其对应满足条件。

第二部分进行满足条件的部分规则执行，处理等。

第三部分进行清除重置。

### 3.规则条件

```
- Pipeline FIFO 		(deq < enq)  
- Bypass FIFO 			(enq < deq)  
- Conflict-Free FIFO 	(enq CF deq)
```

### 4.fromMaybe

```
语法：fromMaybe(defaultValue, maybeValue)
作用：从Maybe类型中提取值，如果为Invalid则返回默认值
```


